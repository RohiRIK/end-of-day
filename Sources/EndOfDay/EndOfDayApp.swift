import AppKit
import EndOfDayCore
import EndOfDayUI
import SwiftUI

@main
struct EndOfDayApp: App {
    @State private var model = EndOfDayModel()

    init() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--snapshot"), idx + 1 < args.count {
            let outDir = URL(fileURLWithPath: args[idx + 1], isDirectory: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor in
                    await SnapshotExporter.exportAll(to: outDir)
                    NSApp.terminate(nil)
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("End of Day", id: EndOfDayModel.mainWindowID) {
            EndOfDayWindow(model: model)
        }
        .defaultSize(width: 780, height: 520)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            EndOfDayCommands(model: model)
        }

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
enum SnapshotExporter {
    static func exportAll(to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = EndOfDayModel()
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: model.summonTheme.isDark ? .darkAqua : .aqua)

        // 1. Menu Bar Panel
        await snapshotView(
            PanelView(model: model)
                .background(Color(nsColor: .windowBackgroundColor)),
            size: NSSize(width: 280, height: 340),
            styleMask: [.titled, .fullSizeContentView],
            title: "End of Day Panel",
            captureThemeFrame: false,
            to: dir.appendingPathComponent("eod-panel.png")
        )

        // 2. Main Window — Work Apps
        model.selectedSidebarSection = .apps
        await snapshotView(
            EndOfDayWindow(model: model),
            size: NSSize(width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            title: "End of Day",
            captureThemeFrame: true,
            to: dir.appendingPathComponent("eod-window-apps.png")
        )

        // 3. Main Window — History
        model.selectedSidebarSection = .stats
        await snapshotView(
            EndOfDayWindow(model: model),
            size: NSSize(width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            title: "End of Day",
            captureThemeFrame: true,
            to: dir.appendingPathComponent("eod-window-history.png")
        )

        // 4. Settings Window
        await snapshotView(
            SettingsView(model: model),
            size: NSSize(width: 580, height: 360),
            styleMask: [.titled, .closable],
            title: "End of Day Settings",
            captureThemeFrame: true,
            to: dir.appendingPathComponent("eod-settings.png")
        )
    }

    private static func snapshotView<V: View>(
        _ rootView: V,
        size: NSSize,
        styleMask: NSWindow.StyleMask,
        title: String,
        captureThemeFrame: Bool,
        to url: URL
    ) async {
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = styleMask
        window.title = title
        window.setContentSize(size)
        window.appearance = NSApp.appearance
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()

        try? await Task.sleep(for: .milliseconds(450))
        window.displayIfNeeded()

        guard let contentView = window.contentView else {
            window.orderOut(nil)
            return
        }
        let targetView = (captureThemeFrame ? contentView.superview : nil) ?? contentView
        targetView.layoutSubtreeIfNeeded()
        let bounds = targetView.bounds
        guard bounds.width > 0, bounds.height > 0,
              let rep = targetView.bitmapImageRepForCachingDisplay(in: bounds) else {
            window.orderOut(nil)
            return
        }
        targetView.cacheDisplay(in: bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url, options: .atomic)
        }
        window.orderOut(nil)
    }
}
