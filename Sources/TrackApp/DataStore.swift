import Foundation
import AppKit

// MARK: - Codable model

private struct StorageFile: Codable {
    // day-string (yyyy-MM-dd) → [bundleID → Record]
    var days: [String: [String: Record]]

    struct Record: Codable {
        var appName: String
        var seconds: TimeInterval
    }
}

// MARK: - DataStore

@MainActor
final class DataStore {

    // ~/Library/Application Support/com.tuum.trackapp/usage.json
    private let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("com.tuum.trackapp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.json")
    }()

    private var storage: StorageFile

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(StorageFile.self, from: data) {
            storage = decoded
        } else {
            storage = StorageFile(days: [:])
        }
    }

    // MARK: Day helper

    static func dayString(for date: Date = Date()) -> String {
        DateFormatter.day.string(from: date)
    }

    // MARK: Restore

    /// Seed tracker with today's persisted totals on launch.
    func restoreToday(into tracker: UsageTracker) {
        let today = Self.dayString()
        guard let records = storage.days[today] else { return }
        for (bundleID, record) in records {
            let icon = iconFromFilesystem(bundleID: bundleID)
            tracker.restore(bundleID: bundleID,
                            name: record.appName,
                            icon: icon,
                            seconds: record.seconds)
        }
    }

    // MARK: Flush

    /// Write current in-memory usages to disk for the given date.
    func flush(usages: [String: UsageTracker.AppUsage], forDate date: Date = Date()) {
        let day = Self.dayString(for: date)
        var dayRecords = storage.days[day] ?? [:]
        for (bundleID, usage) in usages where usage.seconds > 0 {
            dayRecords[bundleID] = StorageFile.Record(appName: usage.name, seconds: usage.seconds)
        }
        storage.days[day] = dayRecords
        save()
    }

    // MARK: Private

    private func save() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func iconFromFilesystem(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - DateFormatter

private extension DateFormatter {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
