import AppKit

@MainActor
final class ActivityMonitor {
    private(set) var currentApp: NSRunningApplication?
    var onChange: ((NSRunningApplication?) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var idleTimer: Timer?
    private var isUserIdle = false

    private let idleThreshold: TimeInterval = 60

    func start() {
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self.update(app)
            }
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update(nil)
            }
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.update(NSWorkspace.shared.frontmostApplication)
            }
        })

        update(NSWorkspace.shared.frontmostApplication)

        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdle()
            }
        }
    }

    private func checkIdle() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let nowIdle = idle > idleThreshold
        if nowIdle && !isUserIdle {
            isUserIdle = true
            update(nil)
        } else if !nowIdle && isUserIdle {
            isUserIdle = false
            update(NSWorkspace.shared.frontmostApplication)
        }
    }

    private func update(_ app: NSRunningApplication?) {
        currentApp = app
        onChange?(app)
    }
}
