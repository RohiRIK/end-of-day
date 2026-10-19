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

/// The menu bar panel: Control Center live module on top, quick actions, and Settings… / Quit in the footer.
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
            liveStatusModule
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .padding(.bottom, 4)

            if let error = model.lastError {
                Text(verbatim: error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }

            if model.isCountingDown || model.isClosingApps {
                countdownModule
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            } else if !model.runningWorkApps.isEmpty {
                runningAppsSection
            }

            PanelDivider()

            CommandRow(
                title: "Run End of Day Now",
                systemImage: "sunset.fill",
                shortcut: "⌘R"
            ) {
                model.triggerNow()
            }
            .disabled(model.runningWorkApps.isEmpty || model.isCountingDown || model.isClosingApps)

            CommandRow(
                title: model.pausedToday ? "Resume Today" : "Pause Today",
                systemImage: model.pausedToday ? "play.circle" : "pause.circle",
                shortcut: "⌘P"
            ) {
                model.togglePauseToday()
            }

            snoozeRow

            PanelDivider()

            CommandRow(
                title: "Open End of Day…",
                systemImage: "macwindow",
                shortcut: "⌘O"
            ) {
                showMainWindow(section: .today)
            }

            CommandRow(
                title: "Select Work Apps (\(model.config.apps.count))…",
                systemImage: "square.grid.2x2",
                shortcut: nil
            ) {
                showMainWindow(section: .apps)
            }

            CommandRow(
                title: "Activity & Stats…",
                systemImage: "chart.bar.xaxis",
                shortcut: nil
            ) {
                showMainWindow(section: .stats)
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
        .frame(width: 316)
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
                showMainWindow(section: .today)
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

    // MARK: - Control Center Live Module

    private var liveStatusModule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: model.pausedToday ? "pause.fill" : "sunset.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("End of Day")
                            .font(.body.weight(.semibold))
                        Spacer()
                        Text(ScheduleEngine.activeDaysSummary(model.config.activeDays))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            }

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    statCell(
                        symbol: "app.badge.checkmark",
                        label: "Running",
                        value: "\(model.runningWorkApps.count) of \(model.config.apps.count)",
                        dotColor: model.runningWorkApps.isEmpty ? .secondary : .green
                    )
                    statCell(
                        symbol: "flame.fill",
                        label: "Streak",
                        value: "\(model.summary.streak) day\(model.summary.streak == 1 ? "" : "s")",
                        dotColor: nil
                    )
                }
                GridRow {
                    statCell(
                        symbol: "calendar",
                        label: "This Month",
                        value: "\(model.summary.monthClosed) closed",
                        dotColor: nil
                    )
                    statCell(
                        symbol: "chart.bar.fill",
                        label: "All Time",
                        value: "\(model.summary.totalClosed) · \(model.summary.totalRuns) runs",
                        dotColor: nil
                    )
                }
            }
        }
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 12, style: .continuous))
    }

    private func statCell(symbol: String, label: String, value: String, dotColor: Color?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
            }
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Countdown Module

    private var countdownModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    model.isClosingApps ? "Closing work apps…" : "Closing in \(model.countdownRemaining)s…",
                    systemImage: "timer"
                )
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                Spacer()
                Text("\(model.runningWorkApps.count) app\(model.runningWorkApps.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Button("Snooze 30m") {
                    model.snooze(minutes: 30)
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

    // MARK: - Running Apps Section

    private var runningAppsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                PanelSectionHeader(title: "Running Work Apps")
                Spacer()
                if model.runningWorkApps.count > 4 {
                    Button("+\(model.runningWorkApps.count - 4) more") {
                        showMainWindow(section: .today)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                }
            }

            ForEach(model.runningWorkApps.prefix(4)) { app in
                RunningAppPanelRow(app: app) {
                    model.quitSingleApp(app.bundleIdentifier)
                }
            }
        }
    }

    // MARK: - Snooze Quick Row

    private var snoozeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "zzz")
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text("Snooze")
            Spacer()
            ForEach([15, 30, 60], id: \.self) { mins in
                Button(mins == 60 ? "1h" : "\(mins)m") {
                    model.snooze(minutes: mins)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 26)
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
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
                .accessibilityLabel("Running")
            Text(verbatim: app.localizedName)
                .lineLimit(1)
            Spacer()
            if hovering {
                Button("Quit", action: onQuit)
                    .controlSize(.mini)
                    .help("Quit \(app.localizedName) now")
            } else {
                Text(app.category)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
