# Project Context

## Overview
`EndOfDay` (`local.summon.end-of-day`) is a native Swift 6 + SwiftUI conversion of `RohiRIK/end-of-day-mac` built as a Summon plugin. It provides both a Control Center–style menu bar extra (`PanelView`) and a full companion `NavigationSplitView` window (`EndOfDayWindow`) plus a `Settings` window (`⌘,`).

## Current State
- Lives in `~/Summon/Apps/end-of-day`, registered in Summon's private project list (`summon project list`).
- Automatically imports existing user configuration and analytics from `~/.config/end_of_day/` into `~/Library/Application Support/local.summon.end-of-day/` while keeping `~/.config/end_of_day/` synchronized when present.
- Defaults active workdays to Sunday–Thursday (`[1, 2, 3, 4, 5]`).
- Watches `~/.config/summon` (`current/theme.json` and `current-theme` -> `themes/<slug>/theme.json`) via `DispatchSource` to apply Summon's accent color and light/dark scheme live.

## Constraints
- Swift 6 strict concurrency, SwiftUI + AppKit bridges (`FitWindowHeight`, `WindowAccessor`), SwiftPM, macOS 15+, zero third-party dependencies.
- Core logic (`EndOfDayCore`) is Foundation-only and tested with `swift-testing` (`EndOfDayCoreTests`).
- Panel footer strictly contains only `Settings…` (`⌘,`) and `Quit End of Day` (`⌘Q`); all preferences live in `SettingsView`.

## Recent History
### 2026-10-20 — Dynamic App Catalog & Dedicated Closing Plan UX
- Replaced static catalog list and checkboxes with dynamic system-wide app discovery (`AppCatalog.discoverInstalledApplications()` scanning `/Applications`, `/System/Applications`, `~/Applications`).
- Implemented automatic category inference (`AppCatalog.inferCategory(...)`) covering Office, Communication, Browsers, Productivity, Dev, Design, Remote/IT, and Other.
- Redesigned `EndOfDayWindow` with a 3-section sidebar (`Closing Plan`, `App Library`, `History`):
  - `ClosingPlanView`: Real-time board showing "Will Close Tonight" with live pulsing status & instant quit/remove actions, "In Closing Plan (Standby)", quick-add suggestion tray for other open applications, and today's closed run history.
  - `AppLibraryView`: Interactive dynamic explorer with category filter pills, count badges, live search, and tactile `+ Add to Plan` / `✓ In Plan` pills (no checkboxes).
- Added comprehensive unit tests in `EndOfDayCoreTests` verifying dynamic scanning, category inference, and deny-list filtering.

### 2026-10-19 — Converted `RohiRIK/end-of-day-mac` into Summon menu bar + full window app
- Built `EndOfDayCore`: `AppCatalog` (35+ categorized work apps with priority tiers), `EndOfDayConfig` & `ConfigStore` (v1/v2 migration + Application Support storage), `ScheduleEngine` (timer calculation, Sun–Thu work week, wake catch-up), `AnalyticsStore` (streak, 7-day bars, 90-day history), `TerminationEngine` (prioritized graceful + force-quit pipeline), and `SummonTheme`.
- Built `EndOfDayUI`: `PanelView` (flat header with schedule, open apps list with native app icons, and clean menu commands), `EndOfDayWindow` (clean 2-section `NavigationSplitView` window for `Work Apps` and `History` with native app icons and zero bundle-ID/picker clutter), and `SettingsView` (`Schedule`, `Shutdown`, and `General` tabs).

