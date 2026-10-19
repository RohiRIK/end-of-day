import AppKit
import SwiftUI

/// The menu bar panel: the app's job on top, Settings… and Quit in the footer.
/// App preferences never go here; they live in SettingsView.
public struct PanelView: View {
    @Environment(\.openSettings) private var openSettings
    private let model: EndOfDayModel

    public init(model: EndOfDayModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EndOfDay")
                .font(.headline)
            Text(model.counter.label)
                .font(.title2.monospacedDigit())
            HStack {
                Button("Add One") { model.increment() }
                    .keyboardShortcut(.defaultAction)
                Button("Reset") { model.reset() }
                    .disabled(model.counter.value == 0)
            }
            Divider()
            HStack {
                Button("Settings…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 260)
    }
}

#Preview("Panel") {
    PanelView(model: EndOfDayModel())
}
