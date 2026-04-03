import Foundation
import Security

enum KeychainService {
    /// Auto-detect Claude Code OAuth token from macOS Keychain.
    /// Claude Code stores credentials under service "Claude Code-credentials".
    static func loadClaudeCodeToken() -> (accessToken: String, orgId: String?)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else {
            return nil
        }

        // Check token hasn't expired
        if let expiresAt = oauth["expiresAt"] as? Double {
            let expiryDate = Date(timeIntervalSince1970: expiresAt / 1000.0)
            if expiryDate < Date() {
                return nil
            }
        }

        let orgId = json["organizationUuid"] as? String
        return (accessToken: accessToken, orgId: orgId)
    }

    static var hasClaudeCodeAuth: Bool {
        loadClaudeCodeToken() != nil
    }
}
