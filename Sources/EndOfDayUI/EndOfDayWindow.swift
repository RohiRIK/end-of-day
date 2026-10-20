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
            case .plan:
                ClosingPlanView(model: model)
            case .apps:
                AppLibraryView(model: model)
            case .stats:
                StatsDetailView(model: model)
            }
        }
        .frame(minWidth: 720, minHeight: 500)
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

// MARK: - Closing Plan View (What Will Close & What Has Closed)

private struct ClosingPlanView: View {
    @Bindable var model: EndOfDayModel

    var body: some View {
        List {
            // Live countdown banner if active
            if model.isCountingDown || model.isClosingApps {
                Section {
                    liveCountdownCard
                }
            } else if let results = model.lastRunResults, !results.isEmpty {
                Section {
                    lastRunReportCard(results)
                }
            }

            // Hero Schedule & Status Header
            Section {
                heroScheduleCard
            }

            // 1. Will Close Tonight (Running Now)
            Section {
                if model.runningWorkApps.isEmpty {
                    emptyRunningCard
                } else {
                    ForEach(model.runningWorkApps) { app in
                        PlanRunningAppCard(
                            app: app,
                            onQuit: {
                                model.quitSingleApp(app.bundleIdentifier)
                            },
                            onRemove: {
                                model.removeAppFromPlan(app.bundleIdentifier)
                            }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Will Close Tonight")
                        .font(.headline)
                    Spacer()
                    if !model.runningWorkApps.isEmpty {
                        Text("\(model.runningWorkApps.count) open")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 2. In Closing Plan (Standby / Closed)
            if !model.planInactiveApps.isEmpty {
                Section {
                    ForEach(model.planInactiveApps) { entry in
                        PlanInactiveAppCard(
                            entry: entry,
                            onRemove: {
                                model.removeAppFromPlan(entry.bundleIdentifier)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("In Closing Plan (Standby)")
                            .font(.headline)
                        Spacer()
                        Text("\(model.planInactiveApps.count) inactive")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 3. Discovered Running on Mac (Quick Add suggestions)
            if !model.unmanagedRunningApps.isEmpty {
                Section {
                    ForEach(model.unmanagedRunningApps.prefix(8)) { app in
                        UnmanagedRunningAppRow(
                            app: app,
                            onAdd: {
                                model.addAppToPlan(app.bundleIdentifier, displayName: app.localizedName)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("Other Open Apps")
                            .font(.headline)
                        Spacer()
                        Text("Click + to add to tonight's plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 4. What Has Closed (Today's Runs)
            if !model.todayClosedEntries.isEmpty {
                Section {
                    ForEach(model.todayClosedEntries) { entry in
                        TodayClosedRow(entry: entry)
                    }
                } header: {
                    Text("Closed Today")
                        .font(.headline)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Closing Plan")
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
                    Label("Snooze", systemImage: "moon.zzz")
                }
                .help("Delay closing tonight")
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

    private var heroScheduleCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: model.pausedToday ? "pause.fill" : "sunset.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.pausedToday ? "Paused for Tonight" : "Tonight's Close Plan")
                    .font(.headline)
                Text(model.scheduleSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.runningWorkApps.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(model.runningWorkApps.isEmpty ? .secondary : Color.accentColor)
                Text(model.runningWorkApps.count == 1 ? "app open" : "apps open")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 8)
    }

    private var emptyRunningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("All Clear — No Scheduled Apps Open")
                    .font(.subheadline.weight(.medium))
                Text("When you open apps that are in your closing plan, they'll appear here ready for tonight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
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

// MARK: - Plan Row Components (Tactile, No Checkboxes)

private struct PlanRunningAppCard: View {
    let app: RunningAppInfo
    let onQuit: () -> Void
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(verbatim: app.localizedName)
                        .font(.body.weight(.medium))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        Text("Running")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }

                Text(verbatim: app.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Quit Now", action: onQuit)
                    .controlSize(.small)
                    .help("Terminate this application right now")

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from tonight's closing plan")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlanInactiveAppCard: View {
    let entry: AppEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleIdentifier: entry.bundleIdentifier, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.canonicalName)
                    .font(.body)

                Text("Closed · In Plan")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(verbatim: entry.category)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1), in: Capsule())

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from plan")
        }
        .padding(.vertical, 2)
    }
}

private struct UnmanagedRunningAppRow: View {
    let app: RunningAppInfo
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(bundleIdentifier: app.bundleIdentifier, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: app.localizedName)
                    .font(.body)
                Text(verbatim: app.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                Label("Add to Plan", systemImage: "plus")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Include this open app in tonight's closing plan")
        }
        .padding(.vertical, 2)
    }
}

private struct TodayClosedRow: View {
    let entry: AnalyticsEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Closed \(entry.appsClosed) app\(entry.appsClosed == 1 ? "" : "s")")
                        .font(.body.weight(.medium))
                    if let time = entry.lastRunTime {
                        Text(verbatim: "at \(time)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if !entry.closedAppNames.isEmpty {
                    Text(verbatim: entry.closedAppNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - App Library View (Dynamic Explorer, No Checkboxes)

private struct AppLibraryView: View {
    @Bindable var model: EndOfDayModel

    var body: some View {
        VStack(spacing: 0) {
            // Category Chips Bar
            categoryChipsBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            Divider()

            // Main App Collection
            List {
                ForEach(model.filteredInstalledApps) { entry in
                    let inPlan = model.config.isSelected(entry.bundleIdentifier)
                    let isRunning = model.allRunningBundleIDs.contains(entry.bundleIdentifier)

                    AppLibraryCard(
                        entry: entry,
                        inPlan: inPlan,
                        isRunning: isRunning,
                        onToggle: {
                            model.toggleApp(entry.bundleIdentifier, displayName: entry.canonicalName)
                        }
                    )
                }
            }
            .listStyle(.inset)
            .overlay {
                if model.filteredInstalledApps.isEmpty {
                    ContentUnavailableView.search(text: model.appSearchQuery)
                }
            }
        }
        .navigationTitle("App Library")
        .navigationSubtitle("\(model.installedApps.count) applications discovered on this Mac")
        .searchable(text: $model.appSearchQuery, placement: .toolbar, prompt: "Search all applications…")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("Select All Open Apps") { model.selectCurrentlyRunningApps() }
                    Button("Select All Common Work Apps") { model.selectAllCatalogApps() }
                    Divider()
                    Button("Clear All from Plan") { model.selectNoApps() }
                } label: {
                    Label("Selection", systemImage: "ellipsis.circle")
                }
                .help("Batch plan selection")
            }
        }
    }

    private var categoryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.availableCategories, id: \.self) { cat in
                    let isSelected = (model.selectedCategoryFilter == cat)
                    Button {
                        model.selectedCategoryFilter = cat
                    } label: {
                        Text(cat)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                isSelected
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AppLibraryCard: View {
    let entry: AppEntry
    let inPlan: Bool
    let isRunning: Bool
    let onToggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleIdentifier: entry.bundleIdentifier, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(verbatim: entry.canonicalName)
                        .font(.body.weight(.medium))

                    if isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Open")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(verbatim: entry.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Visual State Pill (NO CHECKBOX)
            Button(action: onToggle) {
                if inPlan {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                        Text("In Plan")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(Color.accentColor)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                        Text("Add to Plan")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(inPlan ? "Remove from closing plan" : "Add to closing plan")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
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
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(bar.count > 0 ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                                .frame(maxWidth: 32)
                                .frame(height: height)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 88)

                    Text(bar.shortLabel)
                        .font(.caption.weight(bar.isToday ? .semibold : .regular))
                        .foregroundStyle(bar.isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 132)
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
                openMainWindow(model: model, section: .plan, openWindow: openWindow)
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

            Button("Closing Plan") {
                openMainWindow(model: model, section: .plan, openWindow: openWindow)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("App Library") {
                openMainWindow(model: model, section: .apps, openWindow: openWindow)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("History") {
                openMainWindow(model: model, section: .stats, openWindow: openWindow)
            }
            .keyboardShortcut("3", modifiers: .command)
        }
    }
}

#Preview("Main Window") {
    EndOfDayWindow(model: .preview)
}
