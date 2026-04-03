import Foundation

actor ClaudeAPIService {
    /// Ping with a minimal Haiku call to get rate-limit headers.
    /// Both 200 and 429 responses include usage data.
    /// Cost: ~1 Haiku output token per call (essentially free).
    func pingForUsage(accessToken: String) async throws -> ClaudeUsageData {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.91", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = """
        {"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"x"}]}
        """
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw ClaudeAPIError.authenticationFailed
        }

        // Both 200 and 429 include rate-limit headers
        guard http.statusCode == 200 || http.statusCode == 429 else {
            throw ClaudeAPIError.httpError(http.statusCode)
        }

        let headers = http.allHeaderFields
        return ClaudeUsageData(
            session: UsageLimit(
                utilization: parsePercent(headers["anthropic-ratelimit-unified-5h-utilization"]),
                resetAt: parseEpoch(headers["anthropic-ratelimit-unified-5h-reset"])
            ),
            weeklyAll: UsageLimit(
                utilization: parsePercent(headers["anthropic-ratelimit-unified-7d-utilization"]),
                resetAt: parseEpoch(headers["anthropic-ratelimit-unified-7d-reset"])
            ),
            weeklySonnet: nil, // Not available from headers
            lastUpdated: Date()
        )
    }

    /// Identify org via count_tokens (zero quota cost).
    func identifyOrg(accessToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages/count_tokens")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20,token-counting-2024-11-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.91", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = """
        {"model":"claude-sonnet-4-20250514","messages":[{"role":"user","content":"x"}]}
        """
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw ClaudeAPIError.authenticationFailed
        }

        guard let orgId = http.allHeaderFields["anthropic-organization-id"] as? String, !orgId.isEmpty else {
            throw ClaudeAPIError.invalidResponse
        }

        return orgId
    }

    // MARK: - Helpers

    private func parsePercent(_ value: Any?) -> Double {
        // Header value is 0.0-1.0, convert to 0-100
        if let str = value as? String, let d = Double(str) { return d * 100 }
        if let num = value as? NSNumber { return num.doubleValue * 100 }
        return 0
    }

    private func parseEpoch(_ value: Any?) -> Date? {
        let epoch: TimeInterval?
        if let str = value as? String { epoch = TimeInterval(str) }
        else if let num = value as? NSNumber { epoch = num.doubleValue }
        else { return nil }
        guard let e = epoch else { return nil }
        return Date(timeIntervalSince1970: e)
    }
}

enum ClaudeAPIError: LocalizedError {
    case invalidResponse
    case authenticationFailed
    case rateLimited
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Anthropic API"
        case .authenticationFailed: return "OAuth token expired. Re-login with: claude auth login"
        case .rateLimited: return "Rate limited. Will retry shortly."
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}
