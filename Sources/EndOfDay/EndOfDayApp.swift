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

        Settings {
            SettingsView()
        }
    }
}
