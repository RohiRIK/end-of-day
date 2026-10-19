import AppKit
import EndOfDayCore
import SwiftUI

extension SummonTheme {
    public var accentColor: Color {
        let rgb = accentRGB
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    public var accent2Color: Color {
        let rgb = accent2RGB
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    public var colorScheme: ColorScheme {
        isDark ? .dark : .light
    }
}

public extension View {
    @ViewBuilder
    func summonThemed(_ theme: SummonTheme, enabled: Bool) -> some View {
        if enabled {
            self
                .tint(theme.accentColor)
                .preferredColorScheme(theme.colorScheme)
        } else {
            self
        }
    }
}

/// A command row styled like a system menu item: hover highlight, trailing key hint in tertiary.
struct CommandRow: View {
    let title: String
    var systemImage: String? = nil
    var shortcut: String? = nil
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering && isEnabled ? AnyShapeStyle(HierarchicalShapeStyle.quaternary) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { hovering = $0 }
        .help(shortcut.map { "\(title) (\($0))" } ?? title)
    }
}

struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

struct PanelSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

/// Resizes the menu bar window to the panel's height, keeping its top edge under the menu bar.
struct FitWindowHeight: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard let window = view.window, height > 0 else { return }
        let content = window.contentRect(forFrameRect: window.frame)
        guard abs(content.height - height) > 0.5 else { return }
        let fitted = NSRect(x: content.minX, y: content.maxY - height, width: content.width, height: height)
        window.setFrame(window.frameRect(forContentRect: fitted), display: true)
    }
}

/// Raises a newly opened window from an accessory menu bar app so it never lands behind other apps.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowObserverView {
        WindowObserverView(onWindow: onWindow)
    }

    func updateNSView(_ nsView: WindowObserverView, context: Context) {}

    final class WindowObserverView: NSView {
        let onWindow: @MainActor (NSWindow) -> Void

        init(onWindow: @escaping @MainActor (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            Task { @MainActor in
                onWindow(window)
            }
        }
    }
}

/// Helper to raise the main window from a menu bar app following MacUX Windows.md 4-step recipe.
@MainActor
public func openMainWindow(
    model: EndOfDayModel,
    section: SidebarSection? = nil,
    openWindow: OpenWindowAction
) {
    if let section {
        model.selectedSidebarSection = section
    }
    if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
    }
    NSApp.activate()
    openWindow(id: EndOfDayModel.mainWindowID)
}
