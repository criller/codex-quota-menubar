import Foundation
import Darwin

enum QuotaError: Error, LocalizedError {
    case missingCodex, launchFailed, timeout, disconnected, protocolError, loginRequired, serviceUnavailable, noWeeklyWindow, expiredWindow

    var errorDescription: String? {
        switch self {
        case .missingCodex: return "未找到 Codex，请安装或更新 Codex 客户端"
        case .launchFailed: return "无法启动 Codex 额度查询"
        case .timeout: return "查询超时，请稍后刷新"
        case .disconnected: return "Codex 查询已中断，请重试"
        case .protocolError: return "无法识别额度数据，请更新 Codex"
        case .loginRequired: return "请先在 Codex 中登录 ChatGPT 账号"
        case .serviceUnavailable: return "额度服务暂不可用，请检查网络后刷新"
        case .noWeeklyWindow: return "当前账号未返回每周额度"
        case .expiredWindow: return "正在等待新一周的额度数据，请稍后刷新"
        }
    }
}

struct QuotaWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: Double?
}

struct QuotaBucket: Decodable {
    let limitId: String?
    let primary: QuotaWindow?
    let secondary: QuotaWindow?
}

struct QuotaResponse: Decodable {
    let rateLimits: QuotaBucket?
    let rateLimitsByLimitId: [String: QuotaBucket]?

    func weekly(now: Date = Date()) throws -> WeeklyQuota {
        let bucket: QuotaBucket?
        if let codex = rateLimitsByLimitId?["codex"] {
            bucket = codex
        } else if let legacy = rateLimits, legacy.limitId == nil || legacy.limitId == "codex" {
            bucket = legacy
        } else {
            bucket = nil
        }
        guard let bucket,
              let window = [bucket.primary, bucket.secondary].compactMap({ $0 }).first(where: { $0.windowDurationMins == 10080 }),
              window.usedPercent.isFinite else { throw QuotaError.noWeeklyWindow }
        let reset = window.resetsAt.map { Date(timeIntervalSince1970: $0) }
        if let reset, reset <= now { throw QuotaError.expiredWindow }
        return WeeklyQuota(used: min(100, max(0, window.usedPercent)), resetsAt: reset, fetchedAt: now)
    }
}

struct WeeklyQuota {
    let used: Double
    let resetsAt: Date?
    let fetchedAt: Date
    var remaining: Int { Int((100 - used).rounded(.down)) }
    func isFresh(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) < 600 && (resetsAt.map { $0 > now } ?? true)
    }
}

// Own only our short-lived query process. No model turns or conversation reads.
final class CodexQuotaClient: @unchecked Sendable {
    private let lock = NSLock()
    private var activeProcess: Process?

    static func executable() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let suffix = "/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        var candidates = [
            "/Applications/ChatGPT.app" + suffix,
            "/Applications/Codex.app/Contents/Resources/codex",
            home + "/Applications/ChatGPT.app" + suffix,
            home + "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex", home + "/.local/bin/codex"
        ]
        let nvm = home + "/.nvm/versions/node"
        for version in ((try? fm.contentsOfDirectory(atPath: nvm)) ?? []).sorted().reversed() {
            candidates.append(nvm + "/" + version + "/bin/codex")
        }
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }

    func cancel() {
        lock.lock()
        let process = activeProcess
        lock.unlock()
        if let process, process.isRunning { process.terminate() }
    }

    func fetch() throws -> WeeklyQuota {
        signal(SIGPIPE, SIG_IGN)
        guard let executable = Self.executable() else { throw QuotaError.missingCodex }
        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        var environment = ProcessInfo.processInfo.environment
        // Finder/login launches have a minimal PATH; npm Codex needs node next to it.
        environment["PATH"] = executable.deletingLastPathComponent().path + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        // Do not inherit a task-specific remote account or CODEX_HOME from an IDE shell.
        for key in ["CODEX_HOME", "CODEX_API_KEY", "OPENAI_API_KEY", "CODEX_CHATGPT_BASE_URL"] { environment.removeValue(forKey: key) }
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw QuotaError.launchFailed }
        lock.lock(); activeProcess = process; lock.unlock()
        let lifetime = QueryLifetime(process: process)
        let timeout = DispatchWorkItem { lifetime.expire() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30, execute: timeout)
        defer {
            timeout.cancel()
            try? input.fileHandleForWriting.close()
            lifetime.stop()
            try? output.fileHandleForReading.close()
            lock.lock(); activeProcess = nil; lock.unlock()
        }

        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            do { try input.fileHandleForWriting.write(contentsOf: data) }
            catch { throw QuotaError.disconnected }
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "codex_quota_menubar", "title": "Codex Quota", "version": "1.0.0"]]])
        var buffer = Data()
        var bytes = [UInt8](repeating: 0, count: 16384)
        while true {
            // Read a pipe chunk immediately; Foundation's counted reads can wait
            // for more bytes and deadlock the request/response handshake.
            let count = bytes.withUnsafeMutableBytes {
                Darwin.read(output.fileHandleForReading.fileDescriptor, $0.baseAddress, $0.count)
            }
            if count < 0 && errno == EINTR { continue }
            if count <= 0 { throw lifetime.timedOut ? QuotaError.timeout : QuotaError.disconnected }
            buffer.append(contentsOf: bytes.prefix(count))
            if buffer.count > 2_000_000 { throw QuotaError.protocolError }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { continue }
                guard let id = message["id"] as? Int, id == 1 || id == 2 else { continue }
                if let error = message["error"] as? [String: Any] {
                    let description = (error["message"] as? String ?? "").lowercased()
                    if ["auth", "login", "sign in", "chatgpt account", "401"].contains(where: { description.contains($0) }) {
                        throw QuotaError.loginRequired
                    }
                    throw QuotaError.serviceUnavailable
                }
                if id == 1 {
                    try send(["method": "initialized", "params": [:]])
                    try send(["id": 2, "method": "account/rateLimits/read"])
                } else {
                    guard let result = message["result"] else { throw QuotaError.protocolError }
                    do {
                        let data = try JSONSerialization.data(withJSONObject: result)
                        return try JSONDecoder().decode(QuotaResponse.self, from: data).weekly()
                    } catch let error as QuotaError { throw error }
                    catch { throw QuotaError.protocolError }
                }
            }
        }
    }
}

private final class QueryLifetime: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var expired = false
    private var finished = false
    var timedOut: Bool { lock.lock(); defer { lock.unlock() }; return expired }
    init(process: Process) { self.process = process }

    func expire() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        expired = true
        if process.isRunning { process.terminate() }
        lock.unlock()
        forceStopLater()
    }

    private func forceStopLater() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [self] in
            lock.lock(); defer { lock.unlock() }
            if !finished && process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    func stop() {
        if process.isRunning { process.terminate(); forceStopLater() }
        process.waitUntilExit()
        lock.lock(); finished = true; lock.unlock()
    }
}
