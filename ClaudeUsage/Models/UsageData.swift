import Foundation

struct UsageLimit: Codable, Equatable, Sendable {
    let utilization: Double  // 0-100
    let resetAt: Date?

    var percentage: Int { Int(utilization) }

    var resetDescription: String {
        guard let resetAt else { return "Unknown" }
        let now = Date()
        guard resetAt > now else { return "Resetting..." }
        let seconds = Int(resetAt.timeIntervalSince(now))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        }
        return "Resets in \(minutes) min"
    }

    var resetTimeFormatted: String {
        guard let resetAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "Resets \(formatter.string(from: resetAt))"
    }

    var color: UsageColor {
        if utilization >= 90 { return .critical }
        if utilization >= 70 { return .warning }
        return .safe
    }
}

enum UsageColor: Sendable {
    case safe, warning, critical
}

struct ClaudeUsageData: Equatable, Sendable {
    let session: UsageLimit       // 5-hour rolling window
    let weeklyAll: UsageLimit     // 7-day all models
    let weeklySonnet: UsageLimit? // 7-day Sonnet only
    let lastUpdated: Date

    static let empty = ClaudeUsageData(
        session: UsageLimit(utilization: 0, resetAt: nil),
        weeklyAll: UsageLimit(utilization: 0, resetAt: nil),
        weeklySonnet: nil,
        lastUpdated: .distantPast
    )
}

// MARK: - API Response

struct UsageAPIResponse: Codable, Sendable {
    let fiveHour: UsageLimitResponse
    let sevenDay: UsageLimitResponse
    let sevenDaySonnet: UsageLimitResponse?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    func toDomain() -> ClaudeUsageData {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessionReset = fiveHour.resetsAt.flatMap { iso.date(from: $0) }
        let weeklyReset = sevenDay.resetsAt.flatMap { iso.date(from: $0) }

        let sonnet: UsageLimit? = sevenDaySonnet.map {
            UsageLimit(utilization: $0.utilization, resetAt: $0.resetsAt.flatMap { iso.date(from: $0) })
        }

        return ClaudeUsageData(
            session: UsageLimit(utilization: fiveHour.utilization, resetAt: sessionReset),
            weeklyAll: UsageLimit(utilization: sevenDay.utilization, resetAt: weeklyReset),
            weeklySonnet: sonnet,
            lastUpdated: Date()
        )
    }
}

struct UsageLimitResponse: Codable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}
