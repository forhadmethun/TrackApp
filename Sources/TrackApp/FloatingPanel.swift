import AppKit
import SwiftUI
import Combine

@MainActor
final class SidebarState: ObservableObject {
    @Published var isCollapsed = false
}

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?
    private let state = SidebarState()
    private var cancellables = Set<AnyCancellable>()

    private let expandedSize = NSSize(width: 272, height: 408)
    private let collapsedSize = NSSize(width: 72, height: 72)

    func show(tracker: UsageTracker, hudState: HUDState) {
        let view = SidebarView(
            tracker: tracker,
            state: state,
            hudState: hudState,
            onClose: { [weak self] in self?.panel?.orderOut(nil) }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let initialSize = state.isCollapsed ? collapsedSize : expandedSize
        let initialOrigin: CGPoint = {
            if let saved = UserDefaults.standard.string(forKey: "panelFrame") {
                let r = NSRectFromString(saved)
                if r.width > 30 && r.height > 30 { return r.origin }
            }
            if let screen = NSScreen.main {
                let vf = screen.visibleFrame
                return CGPoint(x: vf.maxX - initialSize.width - 16, y: vf.maxY - initialSize.height - 16)
            }
            return CGPoint(x: 100, y: 100)
        }()

        let panel = DraggablePanel(
            contentRect: NSRect(origin: initialOrigin, size: initialSize),
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
        self.panel = panel

        // Clamp the initial frame in case the screen layout shrank since last launch.
        panel.setFrame(clamp(panel.frame, to: panel.screen ?? NSScreen.main), display: false)
        panel.orderFrontRegardless()

        // Resize panel when SwiftUI flips collapse state.
        state.$isCollapsed
            .removeDuplicates()
            .sink { [weak self] collapsed in
                self?.applySize(collapsed: collapsed)
            }
            .store(in: &cancellables)

        // Persist origin on user drag, and clamp drag-to-edge.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                let clamped = self.clamp(panel.frame, to: panel.screen ?? NSScreen.main)
                if clamped != panel.frame {
                    panel.setFrame(clamped, display: true)
                }
                UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "panelFrame")
            }
        }
    }

    func toggleVisibility() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func applySize(collapsed: Bool) {
        guard let panel else { return }
        let target = collapsed ? collapsedSize : expandedSize
        let frame = panel.frame
        // Anchor: keep the visual center fixed while the panel resizes.
        var newFrame = NSRect(
            x: frame.midX - target.width / 2,
            y: frame.midY - target.height / 2,
            width: target.width,
            height: target.height
        )
        newFrame = clamp(newFrame, to: panel.screen ?? NSScreen.main)
        panel.setFrame(newFrame, display: true, animate: true)
    }

    private func clamp(_ rect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen else { return rect }
        let bounds = screen.visibleFrame
        var r = rect
        // Cap size against screen first (in case panel is bigger than screen).
        r.size.width = min(r.size.width, bounds.width)
        r.size.height = min(r.size.height, bounds.height)
        // Push back inside on each edge.
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        return r
    }
}

final class DraggablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
