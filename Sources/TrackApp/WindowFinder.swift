import AppKit
import CoreGraphics

enum WindowFinder {
    /// Returns the frontmost "main" window's frame for the given bundle ID,
    /// converted into NSScreen coordinate space (origin bottom-left, primary
    /// screen at zero). Returns nil if the app has no qualifying on-screen window.
    static func frontWindowFrame(forBundleID bundleID: String?) -> NSRect? {
        guard let bundleID else { return nil }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard let app = apps.first else { return nil }
        let pid = app.processIdentifier

        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let candidates = raw.filter { info in
            guard let owner = info[kCGWindowOwnerPID as String] as? Int32, owner == pid else { return false }
            // Layer 0 = normal app windows. Higher layers are overlays / menus / popovers.
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return false }
            // Some apps publish 0-area placeholder windows; skip them.
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            return w >= 120 && h >= 80
        }

        // Frontmost is first when sorted by window number descending; CGWindowList already
        // returns them front-to-back. Pick the first (frontmost) qualifying window.
        guard let front = candidates.first,
              let bounds = front[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }
        let cg = CGRect(
            x: bounds["X"] ?? 0,
            y: bounds["Y"] ?? 0,
            width: bounds["Width"] ?? 0,
            height: bounds["Height"] ?? 0
        )

        return convertCGToNS(cg)
    }

    /// CG window coords: origin top-left, of the primary display.
    /// NS coords: origin bottom-left, of the primary display.
    /// Flip Y around the primary screen height.
    private static func convertCGToNS(_ cg: CGRect) -> NSRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let nsY = primaryHeight - cg.maxY
        return NSRect(x: cg.minX, y: nsY, width: cg.width, height: cg.height)
    }
}
