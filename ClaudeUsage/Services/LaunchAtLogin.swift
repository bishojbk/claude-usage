import Foundation

enum LaunchAtLogin {
    private static let agentLabel = "com.claudeusage.app"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            install()
        } else {
            uninstall()
        }
    }

    private static func install() {
        // Find the app path — prefer /Applications, fall back to current bundle
        let appPath: String
        let applicationsPath = "/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage"
        if FileManager.default.fileExists(atPath: applicationsPath) {
            appPath = applicationsPath
        } else if let bundlePath = Bundle.main.executablePath {
            appPath = bundlePath
        } else {
            return
        }

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [appPath],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        // Ensure LaunchAgents directory exists
        let dir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write plist
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try? data?.write(to: plistURL)
    }

    private static func uninstall() {
        try? FileManager.default.removeItem(at: plistURL)
    }
}
