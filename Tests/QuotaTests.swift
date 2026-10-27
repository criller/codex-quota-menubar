import Foundation

@main struct QuotaTests {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1000)
        func read(_ json: String) throws -> WeeklyQuota {
            try JSONDecoder().decode(QuotaResponse.self, from: Data(json.utf8)).weekly(now: now)
        }
        func rejects(_ json: String) {
            do { _ = try read(json); fatalError("Expected missing/expired weekly quota") } catch { }
        }
        // Pro: weekly can be primary with no secondary. Missing credit info is irrelevant.
        let pro = try read(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":2000},"secondary":null}}"#)
        precondition(pro.remaining == 93 && pro.isFresh(at: now))
        precondition(!pro.isFresh(at: Date(timeIntervalSince1970: 1600)))
        precondition(!pro.isFresh(at: Date(timeIntervalSince1970: 2000)))
        // Mixed windows: use the seven-day window and prefer the codex bucket over legacy/other meters.
        let mixed = try read(#"{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":10080}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":90,"windowDurationMins":300},"secondary":{"usedPercent":12,"windowDurationMins":10080,"resetsAt":2000}},"other":{"primary":{"usedPercent":80,"windowDurationMins":10080}}}}"#)
        precondition(mixed.remaining == 88)
        // Never invent a full quota when the weekly window is absent or has expired.
        rejects(#"{"rateLimits":{"primary":{"usedPercent":1,"windowDurationMins":300}}}"#)
        rejects(#"{"rateLimits":{"primary":{"usedPercent":1,"windowDurationMins":10080,"resetsAt":999}}}"#)
        rejects(#"{"rateLimits":null,"rateLimitsByLimitId":{"other":{"primary":{"usedPercent":0,"windowDurationMins":10080}}}}"#)
        rejects(#"{"rateLimits":{"limitId":"other","primary":{"usedPercent":0,"windowDurationMins":10080}}}"#)
        // Bounds and decimal usage must not overstate remaining quota.
        let empty = try read(#"{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":10080}}}"#)
        let over = try read(#"{"rateLimits":{"primary":{"usedPercent":101,"windowDurationMins":10080}}}"#)
        let decimal = try read(#"{"rateLimits":{"primary":{"usedPercent":7.4,"windowDurationMins":10080}}}"#)
        precondition(empty.remaining == 0 && over.remaining == 0 && decimal.remaining == 92)
        print("PASS: weekly window selection, bucket priority, expiry/freshness, missing data, percentage bounds")
    }
}
