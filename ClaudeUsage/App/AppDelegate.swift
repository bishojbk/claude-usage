import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState()
    private var pollingService: UsagePollingService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        startPolling()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚡ --"
            button.action = #selector(togglePopover)
            button.target = self
        }

        Task {
            for await _ in appState.$usage.values {
                updateMenuBarText()
            }
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(appState: appState, onRefresh: { [weak self] in
                self?.refreshNow()
            })
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startPolling() {
        pollingService = UsagePollingService(appState: appState)
        pollingService?.start()
    }

    private func refreshNow() {
        pollingService?.refreshNow()
    }

    private func updateMenuBarText() {
        statusItem.button?.title = appState.menuBarText
        statusItem.button?.contentTintColor = appState.menuBarColor
    }
}
