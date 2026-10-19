import AppKit
import EndOfDayCore
import SwiftUI

public struct EndOfDayWindow: View {
    @Bindable var model: EndOfDayModel
    @AppStorage(EndOfDaySettings.useSummonThemeKey) private var useSummonTheme = true

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.selectedSidebarSection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
            .safeAreaInset(edge: .bottom) {
                Text("\(ScheduleEngine.formattedTime(hour: model.config.triggerHour, minute: model.config.triggerMinute)) · \(ScheduleEngine.activeDaysSummary(model.config.activeDays))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        } detail: {
            switch model.selectedSidebarSection {
            case .apps:
                WorkAppsCatalogView(model: model)
            case .stats:
                StatsDetailView(model: model)
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .summonThemed(model.summonTheme, enabled: useSummonTheme)
        .background(
            WindowAccessor { window in
                window.makeKeyAndOrderFront(nil)
                if !NSApp.isActive {
                    NSApp.activate(ignoringOtherApps: true)
                    window.orderFrontRegardless()
                }
            }
        )
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            model.refreshRunningApps()
        }
        .onDisappear {
            let otherVisibleWindows = NSApp.windows.filter { win in
                win.isVisible && win.styleMask.contains(.titled) && win.title != "End of Day"
            }
            if otherVisibleWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - Work Apps View (Main View)

private struct WorkAppsCatalogView: View {
    @Bindable var model: EndOfDayModel

    var body: some View {
        List {
            if model.isCountingDown || model.isClosingApps {
                Section {
                    liveCountdownCard
                }
            } else if let results = model.lastRunResults, !results.isEmpty {
                Section {
                    lastRunReportCard(results)
                }
            }

            if !model.runningWorkApps.isEmpty && model.appSearchQuery.isEmpty {
                Section("Open Now") {
                    ForEach(model.runningWorkApps) { app in
                        HStack(spacing: 10) {
                            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 20)
                            Text(verbatim: app.localizedName)
                                .font(.body.weight(.medium))
                            Spacer()
                            Button("Quit") {
                                model.quitSingleApp(app.bundleIdentifier)
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            ForEach(model.filteredCatalogByCategory, id: \.category) { section in
                Section(section.category) {
                    ForEach(section.entries) { entry in
                        WorkAppCatalogRow(
                            entry: entry,
                            isSelected: model.config.isSelected(entry.bundleIdentifier),
                            isRunning: model.allRunningBundleIDs.contains(entry.bundleIdentifier),
                            onToggle: {
                                model.toggleApp(entry.bundleIdentifier, displayName: entry.canonicalName)
                            }
                        )
                    }
                }
            }
        }
        .overlay {
            if model.filteredCatalogByCategory.isEmpty {
                ContentUnavailableView.search(text: model.appSearchQuery)
            }
        }
        .navigationTitle("Work Apps")
        .navigationSubtitle(model.scheduleSubtitle)
        .searchable(text: $model.appSearchQuery, placement: .toolbar, prompt: "Search apps…")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.togglePauseToday()
                } label: {
                    Label(
                        model.pausedToday ? "Resume Today" : "Pause Today",
                        systemImage: model.pausedToday ? "play.circle" : "pause.circle"
                    )
                }
                .help(model.pausedToday ? "Resume today's schedule (⌘P)" : "Skip tonight without changing your schedule (⌘P)")

                Menu {
                    Toggle("Show Uninstalled Apps", isOn: $model.showUninstalledApps)
                    Divider()
                    Button("Select Installed Apps") { model.selectInstalledApps() }
                    Button("Select Open Apps") { model.selectCurrentlyRunningApps() }
                    Button("Clear Selection") { model.selectNoApps() }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
                .help("App list options")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.triggerNow()
                } label: {
                    Label(
                        model.runningWorkApps.isEmpty
                            ? "Close Apps"
                            : "Close \(model.runningWorkApps.count) Open",
                        systemImage: "sunset.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.runningWorkApps.isEmpty || model.isCountingDown || model.isClosingApps)
                .help("Close open work apps now (⌘R)")
            }
        }
    }

    private var liveCountdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    model.isClosingApps
                        ? "Closing \(model.runningWorkApps.count) work apps…"
                        : "Closing in \(model.countdownRemaining)s…",
                    systemImage: "timer"
                )
                .font(.headline)
                .monospacedDigit()
                Spacer()
                Button("Cancel") {
                    model.cancelCountdown()
                }
                Button("Close Now") {
                    model.confirmCloseNow()
                }
                .buttonStyle(.borderedProminent)
            }
            ProgressView(
                value: Double(max(0, model.countdownRemaining)),
                total: Double(model.countdownTotal)
            )
        }
        .padding(.vertical, 6)
    }

    private func lastRunReportCard(_ results: [AppTerminationResult]) -> some View {
        let succeeded = results.filter(\.success).count
        let failed = results.count - succeeded
        return HStack {
            Label(
                failed == 0
                    ? "Closed \(succeeded) work app\(succeeded == 1 ? "" : "s")"
                    : "Closed \(succeeded), failed \(failed)",
                systemImage: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(failed == 0 ? .green : .orange)
            Spacer()
            Button("Dismiss") {
                model.dismissRunResults()
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

private struct WorkAppCatalogRow: View {
    let entry: AppEntry
    let isSelected: Bool
    let isRunning: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                )
            ) {
                EmptyView()
            }
            .labelsHidden()

            AppIconView(bundleIdentifier: entry.bundleIdentifier, size: 20)

            Text(verbatim: entry.canonicalName)
                .font(.body)

            Spacer()

            if isRunning {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - History View

private struct StatsDetailView: View {
    let model: EndOfDayModel

    private var sortedHistory: [AnalyticsEntry] {
        model.analyticsEntries
            .filter { $0.appsClosed > 0 }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Last 7 Days") {
                SevenDayBarChartView(bars: model.summary.sevenDayBars)
                    .padding(.vertical, 8)
            }

            Section("Past Runs") {
                if sortedHistory.isEmpty {
                    ContentUnavailableView(
                        "No Runs Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("When End of Day closes your work apps, each run appears here.")
                    )
                    .padding(.vertical, 20)
                } else {
                    ForEach(sortedHistory) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(verbatim: entry.date)
                                        .font(.body.monospacedDigit().weight(.medium))
                                    if let time = entry.lastRunTime {
                                        Text(verbatim: time)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if !entry.closedAppNames.isEmpty {
                                    Text(verbatim: entry.closedAppNames.joined(separator: ", "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(entry.appsClosed) closed")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationSubtitle(
            "\(model.summary.streak) day streak · \(model.summary.totalClosed) apps closed"
        )
    }
}

private struct SevenDayBarChartView: View {
    let bars: [DayStatBar]

    private var maxCount: Int {
        max(bars.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(bars) { bar in
                VStack(spacing: 6) {
                    Text("\(bar.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(bar.count > 0 ? .primary : .tertiary)

                    GeometryReader { geo in
                        let ratio = CGFloat(bar.count) / CGFloat(maxCount)
                        let height = max(ratio * geo.size.height, bar.count > 0 ? 8 : 3)
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(bar.count > 0 ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                                .frame(height: height)
                        }
                    }
                    .frame(height: 96)

                    Text(bar.shortLabel)
                        .font(.caption.weight(bar.isToday ? .semibold : .regular))
                        .foregroundStyle(bar.isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 140)
    }
}

// MARK: - Menu Commands

public struct EndOfDayCommands: Commands {
    let model: EndOfDayModel
    @Environment(\.openWindow) private var openWindow

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open End of Day Window") {
                openMainWindow(model: model, section: .apps, openWindow: openWindow)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("End of Day") {
            Button("Close Open Work Apps Now") {
                model.triggerNow()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.runningWorkApps.isEmpty || model.isCountingDown || model.isClosingApps)

            Button(model.pausedToday ? "Resume Today" : "Pause Today") {
                model.togglePauseToday()
            }
            .keyboardShortcut("p", modifiers: .command)

            Menu("Snooze") {
                Button("Snooze 15 min") { model.snooze(minutes: 15) }
                Button("Snooze 30 min") { model.snooze(minutes: 30) }
                Button("Snooze 1 hour") { model.snooze(minutes: 60) }
            }

            Divider()

            Button("Work Apps") {
                openMainWindow(model: model, section: .apps, openWindow: openWindow)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("History") {
                openMainWindow(model: model, section: .stats, openWindow: openWindow)
            }
            .keyboardShortcut("2", modifiers: .command)
        }
    }
}

#Preview("Main Window") {
    EndOfDayWindow(model: .preview)
}
