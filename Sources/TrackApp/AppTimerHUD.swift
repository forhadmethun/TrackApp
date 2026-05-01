import AppKit
import SwiftUI
import Combine

@MainActor
final class HUDState: ObservableObject {
    @Published var isCollapsed = false
}

@MainActor
final class AppTimerHUDController {
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let state = HUDState()
    private var tracker: UsageTracker?
    private var manualOverrideForBundleID: String?

    private let expandedSize = NSSize(width: 280, height: 44)
    private let collapsedSize = NSSize(width: 110, height: 36)

    func show(tracker: UsageTracker) {
        self.tracker = tracker

        let view = AppTimerHUDView(tracker: tracker, state: state)
        let hosting = NSHostingView(rootView: view)

        let panel = HUDPanel(
            contentRect: NSRect(origin: .zero, size: expandedSize),
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
        self.panel = panel

        // Reposition to the active app's window whenever the active app changes.
        tracker.$currentBundleID
            .removeDuplicates()
            .sink { [weak self] bundleID in
                guard let self else { return }
                // New app focused: clear any prior manual override.
                self.manualOverrideForBundleID = nil
                self.dockToActiveWindow(forBundleID: bundleID)
            }
            .store(in: &cancellables)

        // Resize panel when the SwiftUI collapse state flips.
        state.$isCollapsed
            .removeDuplicates()
            .sink { [weak self] collapsed in
                guard let self else { return }
                self.applySize(collapsed: collapsed)
            }
            .store(in: &cancellables)

        // Detect manual user drag — pin pill to that location until next app switch.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Only count user-initiated moves (the mouse must be down).
                if NSEvent.pressedMouseButtons != 0,
                   let id = self.tracker?.currentBundleID {
                    self.manualOverrideForBundleID = id
                }
            }
        }

        applySize(collapsed: state.isCollapsed)
        dockToActiveWindow(forBundleID: tracker.currentBundleID)
        panel.orderFrontRegardless()
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
        // Keep the pill's horizontal center fixed when resizing.
        let newOriginX = frame.midX - target.width / 2
        let newOriginY = frame.maxY - target.height
        panel.setFrame(
            NSRect(x: newOriginX, y: newOriginY, width: target.width, height: target.height),
            display: true,
            animate: true
        )
    }

    private func dockToActiveWindow(forBundleID bundleID: String?) {
        guard let panel else { return }
        // If user has manually placed the pill for this app, leave it alone.
        if let override = manualOverrideForBundleID, override == bundleID { return }

        let pillW = panel.frame.width
        let pillH = panel.frame.height

        let edgeInset: CGFloat = 12
        let newFrame: NSRect = {
            if let win = WindowFinder.frontWindowFrame(forBundleID: bundleID) {
                // Top-right of the active window: pill's right edge sits `edgeInset`
                // inside the window's right edge.
                let x = win.maxX - pillW - edgeInset
                let topY = win.maxY - 6
                let y = topY - pillH
                return NSRect(x: x, y: y, width: pillW, height: pillH)
            }
            // Fallback: top-right of main screen, just below the menu bar.
            if let screen = NSScreen.main {
                let vf = screen.visibleFrame
                return NSRect(
                    x: vf.maxX - pillW - edgeInset,
                    y: vf.maxY - pillH - 6,
                    width: pillW,
                    height: pillH
                )
            }
            return NSRect(x: 200, y: 800, width: pillW, height: pillH)
        }()

        panel.setFrame(clamp(newFrame, to: NSScreen.main), display: true, animate: true)
    }

    private func clamp(_ rect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen else { return rect }
        let bounds = screen.visibleFrame
        var r = rect
        if r.minX < bounds.minX + 4 { r.origin.x = bounds.minX + 4 }
        if r.maxX > bounds.maxX - 4 { r.origin.x = bounds.maxX - 4 - r.width }
        if r.maxY > bounds.maxY - 2 { r.origin.y = bounds.maxY - 2 - r.height }
        if r.minY < bounds.minY + 4 { r.origin.y = bounds.minY + 4 }
        return r
    }
}

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct AppTimerHUDView: View {
    @ObservedObject var tracker: UsageTracker
    @ObservedObject var state: HUDState
    @State private var refreshTick = Date()
    @State private var hovered = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.40), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.20), radius: 4, y: 1)

            content
                .padding(.horizontal, state.isCollapsed ? 10 : 12)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(tracker.currentUsage == nil ? 0.55 : 1.0)
        .animation(.easeOut(duration: 0.25), value: tracker.currentUsage == nil)
        .onReceive(timer) { refreshTick = $0 }
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let usage = tracker.currentUsage {
            HStack(spacing: state.isCollapsed ? 6 : 9) {
                appIcon(usage: usage)

                if !state.isCollapsed {
                    Text(usage.name)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity.combined(with: .move(edge: .leading)))

                    Spacer(minLength: 4)
                }

                Text(formatTime(usage.seconds))
                    .font(.system(state.isCollapsed ? .footnote : .callout, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.78)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if !state.isCollapsed {
                    PulsingDot()
                }

                collapseButton
            }
            .id(usage.id + (state.isCollapsed ? "_c" : "_e"))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.isCollapsed)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: usage.id)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if !state.isCollapsed {
                    Text("Idle")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                collapseButton
            }
        }
    }

    private func appIcon(usage: UsageTracker.AppUsage) -> some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [.purple, .pink, .orange, .purple]),
                        center: .center
                    )
                )
                .frame(width: state.isCollapsed ? 22 : 26, height: state.isCollapsed ? 22 : 26)
                .blur(radius: 2)
                .opacity(0.55)

            if let icon = usage.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: state.isCollapsed ? 18 : 22, height: state.isCollapsed ? 18 : 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.gray.opacity(0.4))
                    .frame(width: state.isCollapsed ? 18 : 22, height: state.isCollapsed ? 18 : 22)
            }
        }
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                state.isCollapsed.toggle()
            }
        } label: {
            Image(systemName: state.isCollapsed ? "chevron.left.2" : "chevron.right.2")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.white.opacity(hovered ? 0.12 : 0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
