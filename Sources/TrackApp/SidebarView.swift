import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var isCollapsed = false
    @State private var refreshTick = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            VStack(spacing: 0) {
                header
                if !isCollapsed {
                    Divider()
                        .opacity(0.2)
                        .padding(.horizontal, 6)
                        .padding(.top, 10)
                    appList
                        .padding(.top, 8)
                    Spacer(minLength: 0)
                    footer
                }
            }
            .padding(14)
        }
        .frame(width: isCollapsed ? 84 : 320, height: isCollapsed ? 84 : 480)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCollapsed)
        .onReceive(timer) { refreshTick = $0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: .green.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            if !isCollapsed {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TRACKING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(formatTotal(tracker.totalSeconds))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                Spacer(minLength: 0)
            }

            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.left.2" : "chevron.right.2")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var appList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                if tracker.sortedTopApps.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(tracker.sortedTopApps.prefix(10))) { app in
                        AppRow(usage: app, total: max(tracker.totalSeconds, 1))
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                    }
                }
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.85),
            value: tracker.sortedTopApps.map(\.id)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
            Text("Switch apps to start tracking")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            PulsingDot()
            Text("Live")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(tracker.usages.count) \(tracker.usages.count == 1 ? "app" : "apps")")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.top, 10)
    }

    private func formatTotal(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}

struct PulsingDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle()
                .fill(.green.opacity(0.4))
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 1.6 : 1.0)
                .opacity(pulse ? 0 : 0.8)
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

struct AppRow: View {
    let usage: UsageTracker.AppUsage
    let total: TimeInterval
    @State private var hovered = false

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, usage.seconds / total))
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 2.5)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .pink, .orange, .purple]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 38, height: 38)
                    .animation(.spring(response: 0.6, dampingFraction: 0.9), value: fraction)
                if let icon = usage.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.gray.opacity(0.3))
                        .frame(width: 22, height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.name)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(formatTime(usage.seconds))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Text("\(Int(fraction * 100))%")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(.white.opacity(0.1))
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovered ? AnyShapeStyle(.white.opacity(0.07)) : AnyShapeStyle(.white.opacity(0.02)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hovered ? .white.opacity(0.12) : .clear, lineWidth: 0.5)
        )
        .scaleEffect(hovered ? 1.015 : 1.0)
        .onHover { h in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { hovered = h }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.isEmphasized = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
