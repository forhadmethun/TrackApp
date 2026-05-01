import AppKit
import SwiftUI

@MainActor
final class AppTimerHUDController {
    private var panel: NSPanel?

    func show(tracker: UsageTracker) {
        let view = AppTimerHUDView(tracker: tracker)
        let hosting = NSHostingView(rootView: view)

        let savedFrame: NSRect = {
            if let saved = UserDefaults.standard.string(forKey: "hudFrame") {
                let r = NSRectFromString(saved)
                if r.width > 80 && r.height > 20 { return r }
            }
            if let screen = NSScreen.main {
                let vf = screen.visibleFrame
                let w: CGFloat = 280
                let h: CGFloat = 44
                return NSRect(x: vf.midX - w / 2, y: vf.maxY - h - 6, width: w, height: h)
            }
            return NSRect(x: 200, y: 800, width: 280, height: 44)
        }()

        let panel = HUDPanel(
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
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "hudFrame")
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

    var isVisible: Bool { panel?.isVisible ?? false }
}

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct AppTimerHUDView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var refreshTick = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.40), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.20), radius: 4, y: 1)

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(tracker.currentUsage == nil ? 0.45 : 1.0)
        .animation(.easeOut(duration: 0.25), value: tracker.currentUsage == nil)
        .onReceive(timer) { refreshTick = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let usage = tracker.currentUsage {
            activeContent(usage: usage)
                .id(usage.id)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    )
                )
        } else {
            idleContent
                .transition(.opacity)
        }
    }

    private func activeContent(usage: UsageTracker.AppUsage) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .pink, .orange, .purple]),
                            center: .center
                        )
                    )
                    .frame(width: 28, height: 28)
                    .blur(radius: 2)
                    .opacity(0.55)

                if let icon = usage.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.gray.opacity(0.4))
                        .frame(width: 22, height: 22)
                }
            }

            Text(usage.name)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Text(formatTime(usage.seconds))
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .monospacedDigit()
                .contentTransition(.numericText())

            PulsingDot()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: usage.seconds)
    }

    private var idleContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Idle")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
