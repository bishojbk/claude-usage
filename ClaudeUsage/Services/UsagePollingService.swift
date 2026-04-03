import Foundation
import UserNotifications

@MainActor
final class UsagePollingService {
    private let appState: AppState
    private let apiService = ClaudeAPIService()
    private var timer: Timer?
    private var lastNotifiedCritical = false
    private var cachedToken: String?

    init(appState: AppState) {
        self.appState = appState
        // Read keychain once at startup and cache
        if let creds = KeychainService.loadClaudeCodeToken() {
            cachedToken = creds.accessToken
        }
        requestNotificationPermission()
    }

    func start() {
        refreshNow()
        rescheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        Task { await refresh() }
    }

    func rescheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(appState.refreshIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    private func refresh() async {
        guard let token = cachedToken else {
            appState.isConfigured = false
            appState.error = "Claude Code not authenticated. Run: claude auth login"
            return
        }

        appState.isConfigured = true
        appState.isLoading = true
        appState.error = nil

        do {
            let usage = try await apiService.pingForUsage(accessToken: token)
            appState.usage = usage
            checkAlerts(usage)
        } catch ClaudeAPIError.authenticationFailed {
            // Token expired — try re-reading from keychain once
            if let creds = KeychainService.loadClaudeCodeToken() {
                cachedToken = creds.accessToken
                do {
                    let usage = try await apiService.pingForUsage(accessToken: creds.accessToken)
                    appState.usage = usage
                    checkAlerts(usage)
                } catch {
                    appState.error = error.localizedDescription
                }
            } else {
                cachedToken = nil
                appState.isConfigured = false
                appState.error = "Token expired. Run: claude auth login"
            }
        } catch {
            appState.error = error.localizedDescription
        }

        appState.isLoading = false
    }

    private func checkAlerts(_ usage: ClaudeUsageData) {
        let isCritical = usage.session.utilization >= 20 || usage.weeklyAll.utilization >= 20
        if isCritical && !lastNotifiedCritical {
            lastNotifiedCritical = true
            sendNotification(
                title: "Claude Usage Alert",
                body: "Session: \(usage.session.percentage)% | Weekly: \(usage.weeklyAll.percentage)%"
            )
        }
        if !isCritical { lastNotifiedCritical = false }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                print("[ClaudeUsage] Notification permission not granted, will use alerts instead")
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        // Try UNUserNotificationCenter first
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "usage-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                // Fallback to Process-based notification for unsigned apps
                DispatchQueue.main.async {
                    self.sendOSANotification(title: title, body: body)
                }
            }
        }

        // Also send via osascript as a reliable fallback
        sendOSANotification(title: title, body: body)
    }

    private func sendOSANotification(title: String, body: String) {
        let script = "display notification \"\(body)\" with title \"\(title)\" sound name \"Glass\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
