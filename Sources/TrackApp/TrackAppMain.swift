import AppKit
import SwiftUI
import ServiceManagement

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
    // Core
    let monitor = ActivityMonitor()
    let tracker = UsageTracker()
    let dataStore = DataStore()

    // UI controllers
    let hudState = HUDState()
    let panelController = FloatingPanelController()
    let hudController = AppTimerHUDController()

    // Timers
    var tickTimer: Timer?
    var flushTimer: Timer?
    var midnightTimer: Timer?

    // Menu bar
    var statusItem: NSStatusItem?
    var launchAtLoginItem: NSMenuItem?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Restore today's persisted usage before the tracker starts ticking.
        dataStore.restoreToday(into: tracker)

        // 2. Start live tracking.
        monitor.onChange = { [weak self] app in
            guard let self else { return }
            self.tracker.tick(currentApp: app)
        }
        monitor.start()

        // 1 Hz tick keeps the current app's counter advancing.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tracker.tick(currentApp: self.monitor.currentApp)
            }
        }

        // 3. Flush to SwiftData every 30 s so a force-quit loses at most 30 s of data.
        flushTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushNow()
            }
        }

        // 4. Midnight reset — fires once at the next calendar midnight, then re-arms.
        scheduleMidnightTimer()

        // 5. Wake-from-sleep guard: if the machine slept over midnight, catch it here.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkDayRollover() }
        }

        // 6. Show UI.
        panelController.show(tracker: tracker, hudState: hudState)
        hudController.show(tracker: tracker, state: hudState)
        setupStatusBar()

        // 7. Record today's day so wake-checks have a reference.
        UserDefaults.standard.set(DataStore.dayString(), forKey: "lastActiveDay")
    }

    // MARK: - Quit

    func applicationWillTerminate(_ notification: Notification) {
        flushNow()
    }

    // MARK: - Flush helpers

    private func flushNow(forDate date: Date = Date()) {
        dataStore.flush(usages: tracker.usages, forDate: date)
    }

    // MARK: - Midnight reset

    private func scheduleMidnightTimer() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        guard let nextMidnight = cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let interval = nextMidnight.timeIntervalSinceNow
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleMidnightReset()
            }
        }
    }

    private func handleMidnightReset() {
        // Date() is now the new day. Flush the accumulated data as yesterday's.
        let yesterday = Date().addingTimeInterval(-60)
        flushNow(forDate: yesterday)
        tracker.reset()
        UserDefaults.standard.set(DataStore.dayString(), forKey: "lastActiveDay")
        scheduleMidnightTimer()   // arm for next midnight
    }

    /// Called after wake — handle any midnight that occurred during sleep.
    private func checkDayRollover() {
        let stored = UserDefaults.standard.string(forKey: "lastActiveDay") ?? ""
        let today = DataStore.dayString()
        if stored != today {
            handleMidnightReset()
        }
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let img = NSImage(systemSymbolName: "hourglass.circle.fill",
                              accessibilityDescription: "TrackApp")
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()

        addItem(menu, title: "Show / Hide Sidebar",    action: #selector(toggleSidebar),   key: "s")
        addItem(menu, title: "Show / Hide App Timer",  action: #selector(toggleHUDAction), key: "t")
        addItem(menu, title: "Reset Today's Stats",    action: #selector(resetStats),      key: "r")

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = launchAtLoginEnabled ? .on : .off
        launchAtLoginItem = loginItem
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TrackApp",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @discardableResult
    private func addItem(_ menu: NSMenu, title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Menu actions

    @objc func toggleSidebar()    { panelController.toggleVisibility() }
    @objc func toggleHUDAction()  { hudState.isVisible.toggle() }
    @objc func resetStats()       { tracker.reset(); flushNow() }

    // MARK: - Launch at login

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
        launchAtLoginItem?.state = launchAtLoginEnabled ? .on : .off
    }
}
