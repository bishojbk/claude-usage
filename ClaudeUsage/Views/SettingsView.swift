import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)

            Divider()

            Form {
                Section("Authentication") {
                    if KeychainService.hasClaudeCodeAuth {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected via Claude Code")
                                .font(.subheadline)
                        }
                        Text("Using OAuth credentials from Claude Code. No setup needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Not connected")
                                .font(.subheadline)
                        }
                        Text("Claude Code is not authenticated. Run this in your terminal:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("claude auth login")
                                .font(.caption.monospaced())
                                .padding(6)
                                .background(.gray.opacity(0.1))
                                .cornerRadius(4)
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("claude auth login", forType: .string)
                            }
                            .controlSize(.small)
                        }
                    }
                }

                Section("General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLogin.setEnabled(newValue)
                        }

                    Picker("Refresh every", selection: $appState.refreshIntervalMinutes) {
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                    }
                }

                Section("Notifications") {
                    Picker("Session alert at", selection: $appState.sessionThreshold) {
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("50%").tag(50)
                        Text("70%").tag(70)
                        Text("80%").tag(80)
                        Text("90%").tag(90)
                    }
                    Picker("Weekly alert at", selection: $appState.weeklyThreshold) {
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("50%").tag(50)
                        Text("70%").tag(70)
                        Text("80%").tag(80)
                        Text("90%").tag(90)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Claude Usage")
                        Spacer()
                        Text("v1.0.0").foregroundColor(.secondary)
                    }
                    Text("Reads OAuth credentials from Claude Code's Keychain entry. Polls Anthropic API with a minimal Haiku call (~0 cost) to read rate-limit headers.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Quit Claude Usage") { NSApp.terminate(nil) }
                        .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 380, height: 380)
    }
}
