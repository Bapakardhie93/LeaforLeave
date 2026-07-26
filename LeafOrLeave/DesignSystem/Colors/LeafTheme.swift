import AppKit
import SwiftUI

private struct LeafAccentColorKey: EnvironmentKey {
    static let defaultValue = LeafColors.accent
}

private struct LeafToolbarIconSizeKey: EnvironmentKey {
    static let defaultValue = BrowserChromeMetrics.toolbarIconSize
}

extension EnvironmentValues {
    var leafAccentColor: Color {
        get { self[LeafAccentColorKey.self] }
        set { self[LeafAccentColorKey.self] = newValue }
    }


    var leafToolbarIconSize: CGFloat {
        get { self[LeafToolbarIconSizeKey.self] }
        set { self[LeafToolbarIconSizeKey.self] = newValue }
    }
}

extension UserAccentColor {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .systemPurple
        red = Double(resolved.redComponent)
        green = Double(resolved.greenComponent)
        blue = Double(resolved.blueComponent)
        opacity = Double(resolved.alphaComponent)
    }
}

struct LeafTheme {
    let background, surface, elevatedSurface, border, primaryText, secondaryText, accent, success, warning, critical, mediaActive: Color
    static func theme(for appearance: LeafAppearance) -> LeafTheme {
        let background: Color = appearance == .graphiteDark
            ? Color(red: 0.055, green: 0.058, blue: 0.064)
            : Color(nsColor: .windowBackgroundColor)
        return .init(
            background: background,
            surface: Color.primary.opacity(0.05),
            elevatedSurface: Color(nsColor: .controlBackgroundColor),
            border: Color.primary.opacity(0.1),
            primaryText: .primary,
            secondaryText: .secondary,
            accent: LeafColors.accent,
            success: .green,
            warning: .orange,
            critical: .red,
            mediaActive: .pink
        )
    }
}

extension LeafAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark, .graphiteDark: .dark
        }
    }

    @MainActor
    func applyToApplication() {
        let appearance: NSAppearance?
        switch self {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark, .graphiteDark:
            appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
            window.contentView?.needsDisplay = true
        }
    }
}

private struct LeafAppearanceModifier: ViewModifier {
    let appearance: LeafAppearance

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance.preferredColorScheme)
            .onAppear { appearance.applyToApplication() }
            .onChange(of: appearance) { _, value in
                value.applyToApplication()
            }
    }
}

extension View {
    func leafAppearance(_ appearance: LeafAppearance) -> some View {
        modifier(LeafAppearanceModifier(appearance: appearance))
    }
}
