import Foundation

struct QuotaWindow: Codable, Equatable, Sendable {
    let usedPercent: Double
    let resetsAt: Date?
    var remaining: Double { max(0, min(100, 100 - usedPercent)) }
    var percentage: String { "\(Int(remaining.rounded(.down)))%" }
}

struct UsageSnapshot: Codable, Equatable, Sendable {
    var weekly: QuotaWindow?
    var fiveHour: QuotaWindow?
    var plan: String?
    var creditBalance: String?
    var resetCardCount: Int?
    var resetCardExpirations: [Date] = []
    var updatedAt: Date?
    var error: String?
    var isOffline = false

    static let empty = UsageSnapshot()
    static let sample = UsageSnapshot(
        weekly: QuotaWindow(usedPercent: 38, resetsAt: Date().addingTimeInterval(172800)),
        fiveHour: QuotaWindow(usedPercent: 16, resetsAt: Date().addingTimeInterval(7200)),
        plan: "plus", creditBalance: "0", resetCardCount: 3,
        resetCardExpirations: [Date().addingTimeInterval(604800)], updatedAt: Date())

    var planLabel: String { plan?.capitalized ?? "未提供" }
    var cardLabel: String { resetCardCount.map { "\($0) 张" } ?? "未提供" }
    var hasData: Bool { weekly != nil || fiveHour != nil }
    func isStale(at date: Date = Date()) -> Bool {
        guard let updatedAt else { return true }
        return isOffline || error != nil || date.timeIntervalSince(updatedAt) > 3600 ||
            [weekly?.resetsAt, fiveHour?.resetsAt].compactMap { $0 }.contains { $0 <= date }
    }

    static func parse(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        let envelope = try JSONDecoder().decode(RPCEnvelope.self, from: data)
        if envelope.error != nil { throw UsageError.rpc }
        guard let result = envelope.result else { throw UsageError.invalidResponse }
        // Only select the Codex pool; other model/credit pools must not substitute for it.
        let pool = result.rateLimitsByLimitId?["codex"] ??
            (result.rateLimits?.limitId == nil || result.rateLimits?.limitId == "codex" ? result.rateLimits : nil)
        let windows = [pool?.primary, pool?.secondary].compactMap { $0 }
        func window(_ minutes: Int) -> QuotaWindow? {
            guard let raw = windows.first(where: { $0.windowDurationMins == minutes }),
                  let used = raw.usedPercent, used.isFinite, (0...100).contains(used) else { return nil }
            return QuotaWindow(usedPercent: used, resetsAt: raw.resetsAt.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil })
        }
        let cards = result.rateLimitResetCredits
        let expirations = (cards?.credits ?? []).filter {
            $0.status == "available" && ($0.resetType == nil || $0.resetType == "codexRateLimits")
        }.compactMap { $0.expiresAt }.filter { $0 > now.timeIntervalSince1970 }.map {
            Date(timeIntervalSince1970: $0)
        }.sorted()
        return UsageSnapshot(weekly: window(10080), fiveHour: window(300), plan: pool?.planType,
                             creditBalance: pool?.credits?.unlimited == true ? "不限" : pool?.credits?.balance,
                             resetCardCount: cards?.availableCount.flatMap { $0 >= 0 ? $0 : nil },
                             resetCardExpirations: expirations, updatedAt: now)
    }
}

enum UsageError: LocalizedError {
    case cliMissing, timeout, rpc, invalidResponse, launch
    var errorDescription: String? {
        switch self {
        case .cliMissing: "未找到 Codex，请在设置中选择程序路径。"
        case .timeout: "查询超时，稍后重试。"
        case .rpc: "Codex 未能返回额度，请检查登录和网络。"
        case .invalidResponse: "Codex 返回的数据格式无法识别。"
        case .launch: "无法启动 Codex，请检查程序路径。"
        }
    }
}

private struct RPCEnvelope: Decodable {
    let result: LimitsResult?
    let error: RPCError?
    struct RPCError: Decodable { let code: Int? }
}
private struct LimitsResult: Decodable {
    let rateLimits: Pool?
    let rateLimitsByLimitId: [String: Pool]?
    let rateLimitResetCredits: ResetCards?
}
private struct Pool: Decodable {
    let limitId: String?
    let primary: RawWindow?
    let secondary: RawWindow?
    let planType: String?
    let credits: Credits?
}
private struct RawWindow: Decodable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: Double?
}
private struct Credits: Decodable {
    let balance: String?
    let unlimited: Bool?
}
private struct ResetCards: Decodable {
    let availableCount: Int?
    let credits: [ResetCard]?
}
private struct ResetCard: Decodable {
    let expiresAt: Double?
    let status: String?
    let resetType: String?
}

enum SnapshotCache {
    static let endpoint = URL(string: "http://127.0.0.1:49763/snapshot")!
    static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("CodexBattery", isDirectory: true).appendingPathComponent("snapshot.json")
    }
    static func load() -> UsageSnapshot {
        guard let data = try? Data(contentsOf: fileURL), let value = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else { return .empty }
        return value
    }
    static func save(_ snapshot: UsageSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        // Also tighten pre-existing directories from older installs before atomic writes.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
