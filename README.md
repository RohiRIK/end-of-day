# EndOfDay

A native macOS menu bar app and full-window companion (`MenuBarExtra` `.window` style + `NavigationSplitView` main window + `Settings` window) that automatically closes configured work apps at the end of your workday. Built the Summon way with Swift 6, SwiftUI, and live Summon theme synchronization.

## Features

- **Menu Bar Panel (`MenuBarExtra` `.window`)**:
  - Control Center–style live status module showing next run time, active day schedule, currently running work apps count, streak, monthly total, and all-time runs.
  - Inline 30-second countdown banner with progress bar, `Close Now`, `Snooze 30m`, and `Cancel`.
  - Quick list of currently running work apps with one-click individual `Quit`.
  - Quick commands: `Run End of Day Now` (`⌘R`), `Pause/Resume Today` (`⌘P`), `Snooze` (`15m` / `30m` / `1h`), `Open End of Day…` (`⌘O`), `Select Work Apps…`, `Activity & Stats…`.
  - Clean footer with `Settings…` (`⌘,`) and `Quit End of Day` (`⌘Q`).
- **Big Companion Window (`EndOfDayWindow`)**:
  - **Today**: Live countdown/report card, running work apps with priority badges and one-click quit, and idle tracked apps.
  - **Work Apps Catalog**: Searchable, filterable (`All`, `Selected`, `Running`, `Installed`) catalog of 35+ work apps across 8 categories (`Office`, `Communication`, `Productivity`, `Browsers`, `Dev`, `Design`, `Remote/IT`, `Other`) with per-app shutdown priority (`1st`, `2nd`, `3rd`).
  - **Activity & Stats**: 7-day bar chart and full run history with closed app breakdowns.
- **Settings Window (`⌘,`)**:
  - **Schedule**: Daily trigger time (`Hour:Minute`), active weekday toggles + presets (`Sun–Thu Work Week`, `Mon–Fri`, `Every Day`), and wake catch-up.
  - **Shutdown**: Soft (`30s Countdown`) vs Hard (`Immediate + Force Quit`) mode and staggered per-app delay (`0–10s`).
  - **General**: `Open at Login` (`SMAppService`), menu bar time toggle, live `~/.config/summon` theme sync, and automatic/manual import from `~/.config/end_of_day/`.

## Layout

| Path | What it is |
|---|---|
| `Sources/EndOfDay/` | `@main` only: `MenuBarExtra`, `Window`, and `Settings` scenes |
| `Sources/EndOfDayUI/` | `PanelView`, `EndOfDayWindow`, `SettingsView`, `Components`, `EndOfDayModel`, `#Preview`s |
| `Sources/EndOfDayCore/` | `AppCatalog`, `EndOfDayConfig`, `ScheduleEngine`, `AnalyticsStore`, `TerminationEngine`, `SummonTheme` |
| `Resources/Info.plist` | Bundle id `local.summon.end-of-day`, `LSUIElement` |
| `Tests/EndOfDayCoreTests/` | `swift-testing` unit test suite |
| `scripts/check.sh` | Quality gate: build, tests, plist lint, and `.app` bundle |

## Build and Run

```bash
scripts/check.sh
open build/EndOfDay.app
```
