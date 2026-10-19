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
                Label {
                    HStack {
                        Text(section.title)
                        Spacer()
                        if section == .today && !model.runningWorkApps.isEmpty {
                            Text("\(model.runningWorkApps.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else if section == .apps {
                            Text("\(model.config.apps.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: section.symbol)
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 260)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ScheduleEngine.formattedTime(hour: model.config.triggerHour, minute: model.config.triggerMinute)) · \(ScheduleEngine.activeDaysSummary(model.config.activeDays))")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                    Text("Theme: \(model.summonTheme.name)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        } detail: {
            switch model.selectedSidebarSection {
            case .today:
                TodayDetailView(model: model)
            case .apps:
                WorkAppsCatalogView(model: model)
            case .stats:
                StatsDetailView(model: model)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
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

// MARK: - Today Detail View

private struct TodayDetailView: View {
    @Bindable var model: EndOfDayModel

    private var idleConfiguredApps: [String] {
        let runningIDs = Set(model.runningWorkApps.map(\.bundleIdentifier))
        return model.config.apps.filter { !runningIDs.contains($0) }
    }

    var body: some View {
        List {
            if model.isCountingDown || model.isClosingApps {
                Section("Live Shutdown") {
                    liveCountdownCard
                }
            } else if let results = model.lastRunResults, !results.isEmpty {
                Section("Last Run Report") {
                    lastRunReportCard(results)
                }
            }

            Section {
                if model.runningWorkApps.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                        Text("No tracked work apps are currently running.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(model.runningWorkApps) { app in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel("Running")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: app.localizedName)
                                    .font(.body.weight(.medium))
                                Text("\(app.category) · \(priorityLabel(app.priority))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let status = model.appCloseStatuses[app.bundleIdentifier] {
                                statusBadge(status)
                            }
                            Button("Quit Now") {
                                model.quitSingleApp(app.bundleIdentifier)
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Running Work Apps (\(model.runningWorkApps.count))")
            }

            Section("Idle Tracked Apps (\(idleConfiguredApps.count))") {
                if idleConfiguredApps.isEmpty {
                    Text("All tracked apps are currently running or none selected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(idleConfiguredApps, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(.quaternary)
                                .frame(width: 8, height: 8)
                            Text(verbatim: AppCatalog.displayName(for: bundleID, customNames: model.config.appDisplayNames))
                            Spacer()
                            Text(AppCatalog.category(for: bundleID))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Today")
        .navigationSubtitle(model.scheduleSubtitle)
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
                    Button("Snooze 15 min") { model.snooze(minutes: 15) }
                    Button("Snooze 30 min") { model.snooze(minutes: 30) }
                    Button("Snooze 1 hour") { model.snooze(minutes: 60) }
                } label: {
                    Label("Snooze", systemImage: "zzz")
                }
                .help("Snooze End of Day trigger")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.triggerNow()
                } label: {
                    Label("Run Now", systemImage: "sunset.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.runningWorkApps.isEmpty || model.isCountingDown || model.isClosingApps)
                .help("Run End of Day countdown now (⌘R)")
            }
        }
    }

    private var liveCountdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    model.isClosingApps
                        ? "Closing \(model.runningWorkApps.count) work apps…"
                        : "Work apps closing in \(model.countdownRemaining)s…",
                    systemImage: "timer"
                )
                .font(.headline)
                .monospacedDigit()
                Spacer()
                Button("Cancel") {
                    model.cancelCountdown()
                }
                Button("Snooze 30 min") {
                    model.snooze(minutes: 30)
                }
                Button("Close Apps Now") {
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
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    failed == 0
                        ? "Closed \(succeeded) work app\(succeeded == 1 ? "" : "s")"
                        : "Closed \(succeeded), failed \(failed)",
                    systemImage: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(failed == 0 ? .green : .orange)
                Spacer()
                Button("Dismiss") {
                    model.dismissRunResults()
                }
                .controlSize(.small)
            }
            ForEach(results) { res in
                HStack {
                    Image(systemName: res.success ? "checkmark.circle" : "xmark.octagon.fill")
                        .foregroundStyle(res.success ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    Text(verbatim: res.appName)
                    Spacer()
                    Text(res.action.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1: "Closes 1st"
        case 3: "Closes Last"
        default: "Normal Order"
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: AppCloseStatus) -> some View {
        switch status {
        case .pending:
            Text("Queued").font(.caption).foregroundStyle(.secondary)
        case .closing:
            ProgressView().controlSize(.small)
        case .closed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }
}

// MARK: - Work Apps Catalog View

private struct WorkAppsCatalogView: View {
    @Bindable var model: EndOfDayModel

    var body: some View {
        List {
            ForEach(model.filteredCatalogByCategory, id: \.category) { section in
                Section(section.category) {
                    ForEach(section.entries) { entry in
                        WorkAppCatalogRow(
                            entry: entry,
                            isSelected: model.config.isSelected(entry.bundleIdentifier),
                            isRunning: model.allRunningBundleIDs.contains(entry.bundleIdentifier),
                            isInstalled: model.installedBundleIDs.contains(entry.bundleIdentifier),
                            priority: AppCatalog.priority(
                                for: entry.bundleIdentifier,
                                overrides: model.config.appPriorities
                            ),
                            onToggle: {
                                model.toggleApp(entry.bundleIdentifier, displayName: entry.canonicalName)
                            },
                            onPriorityChange: { newPriority in
                                model.setPriority(for: entry.bundleIdentifier, priority: newPriority)
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
        .navigationSubtitle("\(model.config.apps.count) selected · \(model.runningWorkApps.count) running now")
        .searchable(text: $model.appSearchQuery, placement: .toolbar, prompt: "Filter work apps…")
        .toolbar {
            ToolbarItemGroup {
                Picker("Filter", selection: $model.appFilterScope) {
                    ForEach(AppFilterScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .help("Filter catalog by status")

                Menu {
                    Button("Select Installed Apps") { model.selectInstalledApps() }
                    Button("Select Running Apps") { model.selectCurrentlyRunningApps() }
                    Divider()
                    Button("Select All Catalog Apps") { model.selectAllCatalogApps() }
                    Button("Select None") { model.selectNoApps() }
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
                .help("Batch select or clear work apps")
            }
        }
    }
}

private struct WorkAppCatalogRow: View {
    let entry: AppEntry
    let isSelected: Bool
    let isRunning: Bool
    let isInstalled: Bool
    let priority: Int
    let onToggle: () -> Void
    let onPriorityChange: (Int) -> Void

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

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(verbatim: entry.canonicalName)
                        .font(.body.weight(isSelected ? .medium : .regular))
                    if isRunning {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Running")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    } else if isInstalled {
                        Text("Installed")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(verbatim: entry.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Picker(
                "Order",
                selection: Binding(
                    get: { priority },
                    set: { onPriorityChange($0) }
                )
            ) {
                Text("1st (Comms)").tag(1)
                Text("2nd (Standard)").tag(2)
                Text("3rd (Dev/Save)").tag(3)
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 120)
            .help("Shutdown order priority")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Activity & Stats Detail View

private struct StatsDetailView: View {
    let model: EndOfDayModel

    private var sortedHistory: [AnalyticsEntry] {
        model.analyticsEntries.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if model.summary.ranToday {
                Section {
                    Label("End of Day has already run today.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Last 7 Days (Apps Closed)") {
                SevenDayBarChartView(bars: model.summary.sevenDayBars)
                    .padding(.vertical, 8)
            }

            Section("Recent Runs (\(sortedHistory.count))") {
                if sortedHistory.isEmpty {
                    ContentUnavailableView(
                        "No Runs Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("When End of Day closes your work apps, each run is recorded here.")
                    )
                    .padding(.vertical, 20)
                } else {
                    ForEach(sortedHistory) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.secondary)
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
                                    Text(verbatim: entry.closedAppNames.joined(separator: " · "))
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
        .navigationTitle("Activity & Stats")
        .navigationSubtitle(
            "Streak: \(model.summary.streak)d · This month: \(model.summary.monthClosed) closed · All time: \(model.summary.totalClosed) apps (\(model.summary.totalRuns) runs)"
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
                openMainWindow(model: model, section: .today, openWindow: openWindow)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("End of Day") {
            Button("Run End of Day Now") {
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

            Button("Today Overview") {
                openMainWindow(model: model, section: .today, openWindow: openWindow)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Work Apps Catalog") {
                openMainWindow(model: model, section: .apps, openWindow: openWindow)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Activity & Stats") {
                openMainWindow(model: model, section: .stats, openWindow: openWindow)
            }
            .keyboardShortcut("3", modifiers: .command)
        }
    }
}

#Preview("Main Window - Today") {
    EndOfDayWindow(model: .preview)
}
