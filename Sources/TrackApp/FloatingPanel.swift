import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?

    func show(tracker: UsageTracker) {
        let view = SidebarView(tracker: tracker)
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let savedFrame: NSRect = {
            if let saved = UserDefaults.standard.string(forKey: "panelFrame") {
                let r = NSRectFromString(saved)
                if r.width > 50 && r.height > 50 { return r }
            }
            if let screen = NSScreen.main {
                let vf = screen.visibleFrame
                return NSRect(x: vf.maxX - 360, y: vf.maxY - 540, width: 320, height: 480)
            }
            return NSRect(x: 100, y: 100, width: 320, height: 480)
        }()

        let panel = DraggablePanel(
            contentRect: savedFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.contentView = hosting
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "panelFrame")
            }
        }

        self.panel = panel
    }

    func toggleVisibility() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
}

final class DraggablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
