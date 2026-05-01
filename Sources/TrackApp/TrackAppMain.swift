import AppKit
import SwiftUI

@main
@MainActor
struct TrackAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = ActivityMonitor()
    let tracker = UsageTracker()
    let panelController = FloatingPanelController()
    let hudController = AppTimerHUDController()
    var statusItem: NSStatusItem?
    var tickTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.onChange = { [weak self] app in
            guard let self else { return }
            self.tracker.tick(currentApp: app)
        }
        monitor.start()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tracker.tick(currentApp: self.monitor.currentApp)
            }
        }

        panelController.show(tracker: tracker)
        hudController.show(tracker: tracker)
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let img = NSImage(systemSymbolName: "hourglass.circle.fill", accessibilityDescription: "TrackApp")
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Show / Hide Sidebar", action: #selector(toggleSidebar), keyEquivalent: "s")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let toggleHUD = NSMenuItem(title: "Show / Hide App Timer", action: #selector(toggleHUDAction), keyEquivalent: "t")
        toggleHUD.target = self
        menu.addItem(toggleHUD)

        let resetItem = NSMenuItem(title: "Reset Today's Stats", action: #selector(resetStats), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TrackApp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func toggleSidebar() {
        panelController.toggleVisibility()
    }

    @objc func toggleHUDAction() {
        hudController.toggleVisibility()
    }

    @objc func resetStats() {
        tracker.reset()
    }
}
