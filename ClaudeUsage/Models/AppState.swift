import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @AppStorage("refreshIntervalMinutes") var refreshIntervalMinutes: Int = 5
    @AppStorage("organizationId") var organizationId: String = ""

    @Published var usage: ClaudeUsageData = .empty
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isConfigured: Bool = false

    var menuBarText: String {
        guard isConfigured, usage.lastUpdated != .distantPast else {
            return "⚡ --"
        }
        let session = usage.session.percentage
        return "⚡ \(session)%"
    }

    var menuBarColor: NSColor? {
        guard isConfigured else { return nil }
        switch usage.session.color {
        case .critical: return .systemRed
        case .warning: return .systemYellow
        case .safe: return nil
        }
    }
}
