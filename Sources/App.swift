import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private let quotaLine = NSMenuItem(title: "正在读取每周额度…", action: nil, keyEquivalent: "")
    private let resetLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let updatedLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var refreshItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var timer: Timer?
    private let client = CodexQuotaClient()
    private var quota: WeeklyQuota?
    private var failure: String?
    private var fetching = false
    private var lastAttempt = Date.distantPast
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Opening the .app twice should keep a single menu-bar item.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        item.button?.setAccessibilityLabel("Codex 每周剩余额度")
        menu.autoenablesItems = false
        menu.delegate = self
        let heading = NSMenuItem(title: "Codex 每周额度", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        for line in [quotaLine, resetLine, updatedLine, errorLine] { line.isEnabled = false; menu.addItem(line) }
        menu.addItem(.separator())
        refreshItem = action("立即刷新", #selector(refresh), "r")
        loginItem = action("开机启动", #selector(toggleLogin))
        menu.addItem(.separator())
        _ = action("退出 Codex 额度", #selector(quit), "q")
        item.menu = menu
        render()
        refresh()
        timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.render()
                let interval: TimeInterval = self.failure == nil ? 300 : 60
                if Date().timeIntervalSince(self.lastAttempt) >= interval { self.refresh() }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func action(_ title: String, _ selector: Selector, _ key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        entry.target = self
        menu.addItem(entry)
        return entry
    }

    func menuWillOpen(_ menu: NSMenu) { render() }

    private func render() {
        guard item != nil else { return }
        let current = quota?.isFresh() == true && failure == nil
        if let quota {
            item.button?.title = current ? "Codex \(quota.remaining)%" : "Codex \(quota.remaining)%!"
            quotaLine.title = current ? "本周剩余 \(quota.remaining)%" : "上次读取：剩余 \(quota.remaining)%（待更新）"
            resetLine.title = quota.resetsAt.map { "重置时间：" + Self.format($0, pattern: "M月d日 EEE HH:mm") } ?? "重置时间：暂未提供"
            resetLine.isHidden = false
            updatedLine.title = "上次更新：" + Self.format(quota.fetchedAt, pattern: "HH:mm:ss")
            updatedLine.isHidden = false
        } else {
            item.button?.title = fetching ? "Codex …" : "Codex --"
            quotaLine.title = fetching ? "正在读取每周额度…" : "暂时无法读取每周额度"
            resetLine.isHidden = true
            updatedLine.isHidden = true
        }
        errorLine.title = failure ?? (current || quota == nil ? "" : "额度数据待更新")
        errorLine.isHidden = errorLine.title.isEmpty
        item.button?.toolTip = "Codex 每周额度\n" + quotaLine.title + (failure.map { "\n" + $0 } ?? "")
        item.button?.setAccessibilityValue(item.button?.title)
        refreshItem?.title = fetching ? "正在刷新…" : "立即刷新"
        refreshItem?.isEnabled = !fetching
        loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem?.title = SMAppService.mainApp.status == .requiresApproval ? "开机启动（待系统批准）" : "开机启动"
    }

    @objc private func refresh() {
        guard !fetching else { return }
        fetching = true
        lastAttempt = Date()
        render()
        let client = self.client
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try client.fetch() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.fetching = false
                switch result {
                case .success(let quota): self.quota = quota; self.failure = nil
                case .failure(let error): self.failure = error.localizedDescription
                }
                self.render()
            }
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else { try SMAppService.mainApp.register() }
        } catch {
            failure = "开机启动设置失败，可稍后重试"
        }
        render()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        client.cancel()
    }

    private static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

@main
struct CodexQuota {
    @MainActor static func main() {
        // A read-only diagnostic path uses the same client as the menu-bar app.
        if CommandLine.arguments.contains("--check") {
            do {
                let quota = try CodexQuotaClient().fetch()
                print("每周剩余：\(quota.remaining)%")
                if let reset = quota.resetsAt { print("重置时间：\(ISO8601DateFormatter().string(from: reset))") }
                exit(0)
            } catch {
                fputs("额度读取失败：\(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
