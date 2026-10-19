# Graph Report - end-of-day  (2026-10-19)

## Corpus Check
- 18 files · ~10,433 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 330 nodes · 746 edges · 20 communities (14 shown, 6 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 68 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5431051c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- EndOfDayModel
- View
- ConfigStore
- Sendable
- EndOfDayConfig
- PanelView
- ScheduleEngine
- SummonTheme
- AppEntry
- WindowAccessor
- Project Context
- EndOfDay
- SettingsView.swift
- SummonTheme
- Color
- Date
- Set
- String
- Color
- SummonTheme

## God Nodes (most connected - your core abstractions)
1. `EndOfDayModel` - 73 edges
2. `EndOfDayConfig` - 23 edges
3. `SummonTheme` - 17 edges
4. `AnalyticsEntry` - 16 edges
5. `PanelView` - 15 edges
6. `SidebarSection` - 13 edges
7. `AnalyticsStore` - 13 edges
8. `AppEntry` - 13 edges
9. `AppCatalog` - 13 edges
10. `.body` - 12 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `CommandRow`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `PanelDivider`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `AppIconView`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `AppIconView`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `FitWindowHeight`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift

## Import Cycles
- None detected.

## Communities (20 total, 6 thin omitted)

### Community 0 - "EndOfDayModel"
Cohesion: 0.09
Nodes (27): AnalyticsStore, AnalyticsSummary, AppCloseStatus, Commands, ConfigStore, Date, DispatchSourceFileSystemObject, EndOfDayConfig (+19 more)

### Community 1 - "View"
Cohesion: 0.06
Nodes (43): AppKit, DayStatBar, EndOfDayCore, EndOfDayUI, Foundation, Observation, AppIconView, .body (+35 more)

### Community 2 - "ConfigStore"
Cohesion: 0.39
Nodes (4): ConfigStore, .defaultApplicationSupportDir, .defaultLegacyDir, URL

### Community 3 - "Sendable"
Cohesion: 0.20
Nodes (14): Sendable, AnalyticsEntry, .id, AnalyticsStore, AnalyticsSummary, DayStatBar, .id, Bool (+6 more)

### Community 4 - "EndOfDayConfig"
Cohesion: 0.07
Nodes (34): async, CaseIterable, Codable, Hashable, EndOfDayConfig, .mode, ShutdownMode, hard (+26 more)

### Community 5 - "PanelView"
Cohesion: 0.08
Nodes (22): App, Identifiable, OpenWindowAction, Scene, EndOfDayApp, .body, openMainWindow(), SidebarSection (+14 more)

### Community 6 - "ScheduleEngine"
Cohesion: 0.22
Nodes (10): ScheduleEngine, Bool, Calendar, Date, Int, String, .menuBarTimeLabel, .scheduleSubtitle (+2 more)

### Community 7 - "SummonTheme"
Cohesion: 0.19
Nodes (14): Double, Equatable, Colors, RGBComponents, SummonTheme, .accent2RGB, .accentRGB, .backgroundRGB (+6 more)

### Community 8 - "AppEntry"
Cohesion: 0.25
Nodes (7): AppCatalog, AppEntry, .id, Int, Set, String, URL

### Community 9 - "WindowAccessor"
Cohesion: 0.21
Nodes (10): Context, MainActor, NSCoder, NSView, NSViewRepresentable, NSWindow, FitWindowHeight, CGFloat (+2 more)

### Community 10 - "Project Context"
Cohesion: 0.29
Nodes (6): 2026-10-19 — Converted `RohiRIK/end-of-day-mac` into Summon menu bar + full window app, Constraints, Current State, Overview, Project Context, Recent History

### Community 11 - "EndOfDay"
Cohesion: 0.40
Nodes (4): Build and Run, EndOfDay, Features, Layout

### Community 12 - "SettingsView.swift"
Cohesion: 0.23
Nodes (9): ServiceManagement, GeneralSettingsTab, .body, ScheduleSettingsTab, SettingsView, .body, ShutdownSettingsTab, Bool (+1 more)

### Community 13 - "SummonTheme"
Cohesion: 0.25
Nodes (7): Color, ColorScheme, SummonTheme, .accent2Color, .accentColor, .colorScheme, Bool

## Knowledge Gaps
- **52 isolated node(s):** `Overview`, `Current State`, `Constraints`, `2026-10-19 — Converted `RohiRIK/end-of-day-mac` into Summon menu bar + full window app`, `.accentColor` (+47 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `EndOfDayModel` connect `EndOfDayModel` to `View`, `Sendable`, `EndOfDayConfig`, `PanelView`, `ScheduleEngine`, `SettingsView.swift`, `SummonTheme`?**
  _High betweenness centrality (0.404) - this node is a cross-community bridge._
- **Why does `SidebarSection` connect `PanelView` to `EndOfDayModel`, `View`, `Sendable`, `EndOfDayConfig`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Why does `WindowAccessor` connect `WindowAccessor` to `View`, `ScheduleEngine`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `EndOfDayModel` (e.g. with `EndOfDayApp` and `.body`) actually correct?**
  _`EndOfDayModel` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `EndOfDayConfig` (e.g. with `.setPriority()` and `.terminationExecution()`) actually correct?**
  _`EndOfDayConfig` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Overview`, `Current State`, `Constraints` to the rest of the system?**
  _52 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `EndOfDayModel` be split into smaller, more focused modules?**
  _Cohesion score 0.08563134978229318 - nodes in this community are weakly interconnected._