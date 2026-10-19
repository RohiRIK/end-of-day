import EndOfDayUI
import SwiftUI

@main
struct EndOfDayApp: App {
    @State private var model = EndOfDayModel()

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
        .defaultSize(width: 860, height: 600)
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
