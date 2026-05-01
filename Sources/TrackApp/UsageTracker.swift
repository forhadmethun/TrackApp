import AppKit
import Combine

@MainActor
final class UsageTracker: ObservableObject {
    struct AppUsage: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: NSImage?
        var seconds: TimeInterval

        static func == (lhs: AppUsage, rhs: AppUsage) -> Bool {
            lhs.id == rhs.id && lhs.seconds == rhs.seconds && lhs.name == rhs.name
        }
    }

    @Published private(set) var usages: [String: AppUsage] = [:]
    private var lastApp: String?
    private var lastTimestamp: Date = Date()

    func tick(currentApp: NSRunningApplication?) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimestamp)

        if let lastID = lastApp, var entry = usages[lastID] {
            entry.seconds += elapsed
            usages[lastID] = entry
        }

        if let app = currentApp, let bundleID = app.bundleIdentifier {
            if usages[bundleID] == nil {
                usages[bundleID] = AppUsage(
                    id: bundleID,
                    name: app.localizedName ?? bundleID,
                    icon: app.icon,
                    seconds: 0
                )
            }
            lastApp = bundleID
        } else {
            lastApp = nil
        }
        lastTimestamp = now
    }

    var sortedTopApps: [AppUsage] {
        usages.values.sorted { $0.seconds > $1.seconds }
    }

    var totalSeconds: TimeInterval {
        usages.values.reduce(0) { $0 + $1.seconds }
    }

    func reset() {
        usages = [:]
        lastApp = nil
        lastTimestamp = Date()
    }
}
