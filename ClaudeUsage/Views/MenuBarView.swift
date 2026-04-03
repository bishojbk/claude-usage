import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    let onRefresh: @MainActor () -> Void

    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isConfigured {
                onboardingView
            } else {
                usageView
            }

            Divider()
            footerView
        }
        .frame(width: 360)
        .sheet(isPresented: $showingSettings) {
            SettingsView(appState: appState)
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Not Connected")
                .font(.subheadline.bold())
            Text("Run `claude auth login` in your terminal, then relaunch.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { showingSettings = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(24)
    }

    // MARK: - Usage

    private var usageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Your usage limits")
                    .font(.headline)
                Spacer()
                if appState.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Error
            if let error = appState.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Session usage
            UsageLimitRow(
                title: "Current session",
                subtitle: appState.usage.session.resetDescription,
                percentage: appState.usage.session.percentage,
                color: appState.usage.session.color
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 16)

            // Weekly limits
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly limits")
                    .font(.headline)
                    .padding(.top, 14)
                    .padding(.bottom, 2)

                UsageLimitRow(
                    title: "All models",
                    subtitle: appState.usage.weeklyAll.resetTimeFormatted,
                    percentage: appState.usage.weeklyAll.percentage,
                    color: appState.usage.weeklyAll.color
                )

                if let sonnet = appState.usage.weeklySonnet {
                    UsageLimitRow(
                        title: "Sonnet only",
                        subtitle: sonnet.utilization > 0 ? sonnet.resetTimeFormatted : "You haven't used Sonnet yet",
                        percentage: sonnet.percentage,
                        color: sonnet.color
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if appState.usage.lastUpdated != .distantPast {
                Text("Last updated: \(timeAgo(appState.usage.lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear").font(.caption)
            }.buttonStyle(.plain)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise").font(.caption)
            }.buttonStyle(.plain)
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle").font(.caption)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

// MARK: - Usage Limit Row

struct UsageLimitRow: View {
    let title: String
    let subtitle: String
    let percentage: Int
    let color: UsageColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: geo.size.width * barFraction)
                    }
                }
                .frame(height: 8)

                Text("\(percentage)% used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 65, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private var barFraction: CGFloat {
        CGFloat(min(max(percentage, 0), 100)) / 100.0
    }

    private var barColor: Color {
        switch color {
        case .safe: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
