# Graph Report - end-of-day  (2026-10-19)

## Corpus Check
- 18 files · ~11,103 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 324 nodes · 782 edges · 12 communities
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 72 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9010ea30`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- EndOfDayModel
- View
- EndOfDayConfig
- Sendable
- RunningAppInfo
- SidebarSection
- ScheduleEngine
- SummonTheme
- AppEntry
- WindowAccessor
- Project Context
- EndOfDay

## God Nodes (most connected - your core abstractions)
1. `EndOfDayModel` - 76 edges
2. `EndOfDayConfig` - 25 edges
3. `AnalyticsEntry` - 18 edges
4. `SummonTheme` - 17 edges
5. `AnalyticsStore` - 15 edges
6. `AppEntry` - 15 edges
7. `RunningAppInfo` - 15 edges
8. `PanelView` - 15 edges
9. `AppTerminationResult` - 14 edges
10. `SidebarSection` - 14 edges

## Surprising Connections (you probably didn't know these)
- `.body` --references--> `AppEntry`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayCore/AppCatalog.swift
- `.body` --calls--> `CommandRow`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `PanelDivider`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `FitWindowHeight`  [INFERRED]
  Sources/EndOfDayUI/PanelView.swift → Sources/EndOfDayUI/Components.swift
- `.body` --calls--> `WindowAccessor`  [INFERRED]
  Sources/EndOfDayUI/EndOfDayWindow.swift → Sources/EndOfDayUI/Components.swift

## Import Cycles
- None detected.

## Communities (12 total, 0 thin omitted)

### Community 0 - "EndOfDayModel"
Cohesion: 0.06
Nodes (45): App, Commands, DispatchSourceFileSystemObject, Int32, NSObjectProtocol, OpenWindowAction, Scene, ServiceManagement (+37 more)

### Community 1 - "View"
Cohesion: 0.06
Nodes (39): AppKit, ColorScheme, EndOfDayUI, CommandRow, .body, PanelDivider, .body, PanelSectionHeader (+31 more)

### Community 2 - "EndOfDayConfig"
Cohesion: 0.12
Nodes (17): ConfigStore, .defaultApplicationSupportDir, .defaultLegacyDir, EndOfDayConfig, .mode, ShutdownMode, hard, .id (+9 more)

### Community 3 - "Sendable"
Cohesion: 0.18
Nodes (16): Equatable, Identifiable, Sendable, AnalyticsEntry, .id, AnalyticsStore, AnalyticsSummary, DayStatBar (+8 more)

### Community 4 - "RunningAppInfo"
Cohesion: 0.11
Nodes (21): async, Codable, Hashable, AppCloseStatus, closed, closing, failed, pending (+13 more)

### Community 5 - "SidebarSection"
Cohesion: 0.09
Nodes (20): CaseIterable, EndOfDayCore, Foundation, Observation, AppFilterScope, all, .id, installed (+12 more)

### Community 6 - "ScheduleEngine"
Cohesion: 0.22
Nodes (10): ScheduleEngine, Bool, Calendar, Date, Int, String, .menuBarTimeLabel, .scheduleSubtitle (+2 more)

### Community 7 - "SummonTheme"
Cohesion: 0.19
Nodes (13): Double, Colors, RGBComponents, SummonTheme, .accent2RGB, .accentRGB, .backgroundRGB, .foregroundRGB (+5 more)

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

## Knowledge Gaps
- **59 isolated node(s):** `Overview`, `Current State`, `Constraints`, `2026-10-19 — Converted `RohiRIK/end-of-day-mac` into Summon menu bar + full window app`, `Features` (+54 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `EndOfDayModel` connect `EndOfDayModel` to `View`, `EndOfDayConfig`, `Sendable`, `RunningAppInfo`, `SidebarSection`, `ScheduleEngine`, `AppEntry`?**
  _High betweenness centrality (0.442) - this node is a cross-community bridge._
- **Why does `View` connect `View` to `EndOfDayModel`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Why does `EndOfDayConfig` connect `EndOfDayConfig` to `EndOfDayModel`, `Sendable`, `RunningAppInfo`, `SidebarSection`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `EndOfDayModel` (e.g. with `EndOfDayApp` and `.body`) actually correct?**
  _`EndOfDayModel` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `EndOfDayConfig` (e.g. with `.setPriority()` and `.terminationExecution()`) actually correct?**
  _`EndOfDayConfig` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Overview`, `Current State`, `Constraints` to the rest of the system?**
  _59 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `EndOfDayModel` be split into smaller, more focused modules?**
  _Cohesion score 0.05555555555555555 - nodes in this community are weakly interconnected._