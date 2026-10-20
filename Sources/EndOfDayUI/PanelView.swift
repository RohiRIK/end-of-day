import AppKit
import EndOfDayCore
import SwiftUI

public struct MenuBarLabel: View {
    let model: EndOfDayModel
    @AppStorage(EndOfDaySettings.showTimeInMenuBarKey) private var showTime = false

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            if showTime || model.isCountingDown {
                Text(model.menuBarTimeLabel)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("End of Day, \(model.scheduleSubtitle)")
    }

    private var iconName: String {
        if model.isCountingDown || model.isClosingApps {
            return "timer"
        }
        if model.pausedToday {
            return "pause.circle"
        }
        if let snoozed = model.snoozedUntil, snoozed > Date() {
            return "zzz"
        }
        return "sunset.fill"
    }
}

/// Calm, flat menu bar panel: header with schedule, open work apps list (when any are running), and clean menu commands.
public struct PanelView: View {
    let model: EndOfDayModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @AppStorage(EndOfDaySettings.useSummonThemeKey) private var useSummonTheme = true
    @FocusState private var focused: Bool
    @State private var height: CGFloat = 0

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerSection
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            if let error = model.lastError {
                Text(verbatim: error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }

            if model.isCountingDown || model.isClosingApps {
                countdownBanner
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            } else if !model.runningWorkApps.isEmpty {
                PanelDivider()
                openAppsSection
            }

            PanelDivider()

            CommandRow(
                title: closeNowLabel,
                systemImage: "sunset.fill",
                shortcut: "⌘R"
            ) {
                model.triggerNow()
            }
            .disabled(model.runningWorkApps.isEmpty || model.isCountingDown || model.isClosingApps)

            CommandRow(
                title: model.pausedToday ? "Resume Schedule Today" : "Pause Schedule Today",
                systemImage: model.pausedToday ? "play.circle" : "pause.circle",
                shortcut: "⌘P"
            ) {
                model.togglePauseToday()
            }

            CommandRow(
                title: "Snooze 30 Minutes",
                systemImage: "zzz",
                shortcut: nil
            ) {
                model.snooze(minutes: 30)
            }

            PanelDivider()

            CommandRow(
                title: "Open End of Day…",
                systemImage: "macwindow",
                shortcut: "⌘O"
            ) {
                showMainWindow(section: .plan)
            }

            PanelDivider()

            CommandRow(title: "Settings…", shortcut: "⌘,") {
                showSettings()
            }

            CommandRow(title: "Quit End of Day", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
        }
        .padding(6)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background(FitWindowHeight(height: height))
        .summonThemed(model.summonTheme, enabled: useSummonTheme)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            focused = true
            model.refreshRunningApps()
        }
        .onKeyPress(.escape) {
            if model.isCountingDown {
                model.cancelCountdown()
            } else {
                dismiss()
            }
            return .handled
        }
        .onKeyPress(keys: ["r", "p", "o", ",", "q"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            switch press.key {
            case "r":
                if !model.runningWorkApps.isEmpty { model.triggerNow() }
            case "p":
                model.togglePauseToday()
            case "o":
                showMainWindow(section: .plan)
            case ",":
                showSettings()
            case "q":
                NSApp.terminate(nil)
            default:
                return .ignored
            }
            return .handled
        }
    }

    private var closeNowLabel: String {
        let count = model.runningWorkApps.count
        guard count > 0 else { return "Close Work Apps Now" }
        return "Close \(count) Open App\(count == 1 ? "" : "s") Now"
    }

    // MARK: - Clean Flat Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: model.pausedToday ? "pause.fill" : "sunset.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 1) {
                Text("End of Day")
                    .font(.body.weight(.semibold))

                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(
                        ScheduleEngine.nextRunSummary(
                            nextFireDate: model.nextFireDate,
                            pausedToday: model.pausedToday,
                            snoozedUntil: model.snoozedUntil,
                            now: context.date
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Countdown Banner

    private var countdownBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    model.isClosingApps ? "Closing work apps…" : "Closing in \(model.countdownRemaining)s…",
                    systemImage: "timer"
                )
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                Spacer()
            }

            ProgressView(
                value: Double(max(0, model.countdownRemaining)),
                total: Double(model.countdownTotal)
            )
            .controlSize(.small)

            HStack(spacing: 6) {
                Button("Cancel") {
                    model.cancelCountdown()
                }
                .controlSize(.small)

                Spacer()

                Button("Close Now") {
                    model.confirmCloseNow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Open Work Apps Section

    private var openAppsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            PanelSectionHeader(title: "Open Now")

            ForEach(model.runningWorkApps.prefix(5)) { app in
                RunningAppPanelRow(app: app) {
                    model.quitSingleApp(app.bundleIdentifier)
                }
            }
        }
    }

    // MARK: - Navigation Helpers

    private func showMainWindow(section: SidebarSection) {
        dismiss()
        openMainWindow(model: model, section: section, openWindow: openWindow)
    }

    private func showSettings() {
        dismiss()
        NSApp.activate()
        openSettings()
    }
}

private struct RunningAppPanelRow: View {
    let app: RunningAppInfo
    let onQuit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 16)
            Text(verbatim: app.localizedName)
                .lineLimit(1)
            Spacer()
            if hovering {
                Button("Quit", action: onQuit)
                    .controlSize(.mini)
                    .help("Quit \(app.localizedName) now")
            } else {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Open")
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 24)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? AnyShapeStyle(HierarchicalShapeStyle.quaternary) : AnyShapeStyle(Color.clear))
        )
        .onHover { hovering = $0 }
    }
}

#Preview("Panel") {
    PanelView(model: .preview)
}
