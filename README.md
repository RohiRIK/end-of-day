# EndOfDay

A menu bar app: a status item with a panel (`MenuBarExtra`, `.window` style), `LSUIElement`, no Dock icon. Made with Summon from its menu bar app template.

## Layout

| Path | What it is |
|---|---|
| `Sources/EndOfDay/` | `@main` only: the `MenuBarExtra` and `Settings` scenes |
| `Sources/EndOfDayUI/` | Panel, Settings window, `@Observable` model, `#Preview`s |
| `Sources/EndOfDayCore/` | Logic, Foundation only, tested |
| `Resources/Info.plist` | Bundle id `local.summon.end-of-day`, `LSUIElement` |
| `Tests/EndOfDayCoreTests/` | swift-testing |
| `scripts/check.sh` | The gate: build, tests, and the rest; writes `build/check-report.md` |

## Build and run

```bash
scripts/check.sh
scripts/bundle.sh            # build/EndOfDay.app
open build/EndOfDay.app
```

Requires macOS 15+ and Swift 6. No third-party dependencies.
