# Graph Report - end-of-day  (2026-10-19)

## Corpus Check
- 18 files · ~10,743 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 347 nodes · 763 edges · 24 communities (13 shown, 11 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 69 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `99fe653d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- EndOfDayModel
- Components.swift
- ConfigStore
- Sendable
- EndOfDayConfig
- PanelView
- ScheduleEngine
- SummonTheme
- AppEntry
- Foundation
- Project Context
- EndOfDay
- View
- AnalyticsEntry
- Color
- Date
- Set
- String
- Color
- SummonTheme
- AppEntry
- AppTerminationResult
- Int
- Void

## God Nodes (most connected - your core abstractions)
1. `EndOfDayModel` - 61 edges
2. `EndOfDayConfig` - 23 edges
3. `SummonTheme` - 17 edges
4. `PanelView` - 16 edges
5. `AnalyticsEntry` - 16 edges
6. `SidebarSection` - 13 edges
7. `AnalyticsStore` - 13 edges
8. `AppEntry` - 13 edges
9. `AppCatalog` - 13 edges
10. `DayStatBar` - 12 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `MenuBarLabel`  [INFERRED]
  Sources/EndOfDay/EndOfDayApp.swift → Sources/EndOfDayUI/PanelView.swift
- `.body` --calls--> `PanelView`  [INFERRED]
  Sources/EndOfDay/EndOfDayApp.swift → Sources/EndOfDayUI/PanelView.swift
- `.body` --calls--> `WindowAccessor`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `AppIconView`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayUI/Components.swift
- `.body` --references--> `AppEntry`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayCore/AppCatalog.swift

## Import Cycles
- None detected.

## Communities (24 total, 11 thin omitted)

### Community 0 - "EndOfDayModel"
Cohesion: 0.09
Nodes (27): AnalyticsStore, AnalyticsSummary, AppCloseStatus, ConfigStore, Date, DispatchSourceFileSystemObject, EndOfDayConfig, Int32 (+19 more)

### Community 1 - "Components.swift"
Cohesion: 0.07
Nodes (34): Color, ColorScheme, Context, MainActor, NSCoder, NSView, NSViewRepresentable, NSWindow (+26 more)

### Community 2 - "ConfigStore"
Cohesion: 0.39
Nodes (4): ConfigStore, .defaultApplicationSupportDir, .defaultLegacyDir, URL

### Community 3 - "Sendable"
Cohesion: 0.19
Nodes (15): Identifiable, Sendable, AnalyticsEntry, .id, AnalyticsStore, AnalyticsSummary, DayStatBar, .id (+7 more)

### Community 4 - "EndOfDayConfig"
Cohesion: 0.08
Nodes (33): async, CaseIterable, Codable, Hashable, EndOfDayConfig, .mode, ShutdownMode, hard (+25 more)

### Community 5 - "PanelView"
Cohesion: 0.11
Nodes (16): OpenWindowAction, openMainWindow(), SidebarSection, apps, .id, stats, .symbol, .title (+8 more)

### Community 6 - "ScheduleEngine"
Cohesion: 0.21
Nodes (11): ScheduleEngine, Bool, Calendar, Date, Int, String, .menuBarTimeLabel, .scheduleSubtitle (+3 more)

### Community 7 - "SummonTheme"
Cohesion: 0.20
Nodes (14): Double, Equatable, Colors, RGBComponents, SummonTheme, .accent2RGB, .accentRGB, .backgroundRGB (+6 more)

### Community 8 - "AppEntry"
Cohesion: 0.25
Nodes (7): AppCatalog, AppEntry, .id, Int, Set, String, URL

### Community 9 - "Foundation"
Cohesion: 0.09
Nodes (18): App, AppKit, EndOfDayCore, EndOfDayUI, Foundation, NSSize, Observation, Scene (+10 more)

### Community 10 - "Project Context"
Cohesion: 0.29
Nodes (6): 2026-10-19 — Converted `RohiRIK/end-of-day-mac` into Summon menu bar + full window app, Constraints, Current State, Overview, Project Context, Recent History

### Community 11 - "EndOfDay"
Cohesion: 0.40
Nodes (4): Build and Run, EndOfDay, Features, Layout

### Community 12 - "View"
Cohesion: 0.08
Nodes (31): AnalyticsEntry, AppEntry, AppTerminationResult, Commands, DayStatBar, Int, ServiceManagement, .body (+23 more)

## Knowledge Gaps
- **52 isolated node(s):** `EndOfDayUI`, `.sortedHistory`, `.maxCount`, `.body`, `ServiceManagement` (+47 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `EndOfDayModel` connect `EndOfDayModel` to `Components.swift`, `Sendable`, `EndOfDayConfig`, `PanelView`, `ScheduleEngine`, `Foundation`, `View`?**
  _High betweenness centrality (0.329) - this node is a cross-community bridge._
- **Why does `SidebarSection` connect `PanelView` to `EndOfDayModel`, `Foundation`, `Sendable`, `EndOfDayConfig`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Why does `PanelView` connect `PanelView` to `EndOfDayModel`, `Components.swift`, `ScheduleEngine`, `Foundation`, `View`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `EndOfDayModel` (e.g. with `.body` and `.openAppsSection`) actually correct?**
  _`EndOfDayModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `EndOfDayConfig` (e.g. with `.setPriority()` and `.terminationExecution()`) actually correct?**
  _`EndOfDayConfig` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `EndOfDayUI`, `.sortedHistory`, `.maxCount` to the rest of the system?**
  _52 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `EndOfDayModel` be split into smaller, more focused modules?**
  _Cohesion score 0.0899854862119013 - nodes in this community are weakly interconnected._