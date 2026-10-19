import EndOfDayCore
import ServiceManagement
import SwiftUI

/// The Settings window (⌘,): every app preference lives here, never in the menu bar panel.
public struct SettingsView: View {
    @Bindable var model: EndOfDayModel
    @AppStorage(EndOfDaySettings.useSummonThemeKey) private var useSummonTheme = true

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            ScheduleSettingsTab(model: model)
                .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }

            ShutdownSettingsTab(model: model)
                .tabItem { Label("Shutdown", systemImage: "power") }

            GeneralSettingsTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 580)
        .fixedSize(horizontal: false, vertical: true)
        .summonThemed(model.summonTheme, enabled: useSummonTheme)
    }
}

private struct ScheduleSettingsTab: View {
    @Bindable var model: EndOfDayModel

    var body: some View {
        Form {
            Section("Daily Trigger Time") {
                HStack(spacing: 16) {
                    Text("Close work apps at")
                    Spacer()
                    Picker(
                        "Hour",
                        selection: Binding(
                            get: { model.config.triggerHour },
                            set: {
                                model.config.triggerHour = $0
                                model.saveConfig()
                            }
                        )
                    ) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 68)

                    Text(":")
                        .font(.headline.monospacedDigit())

                    Picker(
                        "Minute",
                        selection: Binding(
                            get: { model.config.triggerMinute },
                            set: {
                                model.config.triggerMinute = $0
                                model.saveConfig()
                            }
                        )
                    ) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 68)
                }

                Toggle(
                    "Catch up on wake if trigger time passed while asleep",
                    isOn: Binding(
                        get: { model.config.catchUpOnWake },
                        set: {
                            model.config.catchUpOnWake = $0
                            model.saveConfig()
                        }
                    )
                )
            }

            Section("Active Days") {
                HStack(spacing: 8) {
                    ForEach(ScheduleEngine.weekdayLabels, id: \.weekday) { day in
                        let isOn = model.config.isDayActive(day.weekday)
                        Button {
                            model.toggleDay(day.weekday)
                        } label: {
                            Text(day.short)
                                .font(.callout.weight(isOn ? .semibold : .regular))
                                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Text("Presets")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sun–Thu (Work Week)") {
                        model.setActiveDaysPreset([1, 2, 3, 4, 5])
                    }
                    .controlSize(.small)

                    Button("Mon–Fri") {
                        model.setActiveDaysPreset([2, 3, 4, 5, 6])
                    }
                    .controlSize(.small)

                    Button("Every Day") {
                        model.setActiveDaysPreset([])
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShutdownSettingsTab: View {
    @Bindable var model: EndOfDayModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Shutdown Behavior") {
                Picker(
                    "Shutdown mode",
                    selection: Binding(
                        get: { model.config.mode },
                        set: {
                            model.config.mode = $0
                            model.saveConfig()
                        }
                    )
                ) {
                    ForEach(ShutdownMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Stepper(
                    value: Binding(
                        get: { model.config.closeDelaySeconds },
                        set: {
                            model.config.closeDelaySeconds = $0
                            model.saveConfig()
                        }
                    ),
                    in: 0...10
                ) {
                    LabeledContent(
                        "Delay between apps",
                        value: model.config.closeDelaySeconds == 0
                            ? "No delay"
                            : "\(model.config.closeDelaySeconds)s between each app"
                    )
                }
            }

            Section("Tracked Work Apps") {
                LabeledContent("Selected apps", value: "\(model.config.apps.count) apps")
                HStack {
                    Button("Select Installed Apps") {
                        model.selectInstalledApps()
                    }
                    Button("Select Running Apps") {
                        model.selectCurrentlyRunningApps()
                    }
                    Spacer()
                    Button("Open Work Apps Catalog…") {
                        openMainWindow(model: model, section: .apps, openWindow: openWindow)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettingsTab: View {
    let model: EndOfDayModel
    @AppStorage(EndOfDaySettings.showTimeInMenuBarKey) private var showTime = false
    @AppStorage(EndOfDaySettings.useSummonThemeKey) private var useSummonTheme = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Menu Bar & Startup") {
                Toggle("Open at Login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in
                        setOpenAtLogin(enabled)
                    }
                if let loginError {
                    Text(verbatim: loginError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Toggle("Show next trigger time in the menu bar", isOn: $showTime)
            }

            Section("Appearance") {
                Toggle("Follow Summon theme (~/.config/summon)", isOn: $useSummonTheme)
                LabeledContent("Current Summon theme", value: "\(model.summonTheme.name) (\(model.summonTheme.appearance))")
            }

            Section("Data & Legacy Migration") {
                LabeledContent("Storage", value: "~/Library/Application Support/local.summon.end-of-day/")
                HStack {
                    Text("Import schedule & analytics from ~/.config/end_of_day")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Import Now") {
                        model.importFromLegacyConfig()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "Allow End of Day in System Settings › General › Login Items."
                : nil
        } catch {
            loginError = error.localizedDescription
        }
    }
}

#Preview("Settings") {
    SettingsView(model: .preview)
}
