import AppKit
import SwiftUI

private struct LeafAccentColorKey: EnvironmentKey {
    static let defaultValue = LeafColors.accent
}

private struct LeafToolbarIconSizeKey: EnvironmentKey {
    static let defaultValue = BrowserChromeMetrics.toolbarIconSize
}

private struct LeafAppearanceKey: EnvironmentKey {
    static let defaultValue = LeafAppearance.system
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

    var leafAppearance: LeafAppearance {
        get { self[LeafAppearanceKey.self] }
        set { self[LeafAppearanceKey.self] = newValue }
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

extension UIAccent {
    var color: Color {
        switch self {
        case .violet: LeafColors.accent
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        }
    }
}

extension SettingsData {
    func resolvedAccentColor(workspaceAccent: String? = nil) -> Color {
        if useCustomAccent {
            return customAccent.color
        }
        if useWorkspaceAccent, let workspaceAccent {
            switch workspaceAccent {
            case "blue": return .blue
            case "teal": return .teal
            case "green": return .green
            case "orange": return .orange
            case "pink": return .pink
            default: return LeafColors.accent
            }
        }
        return accent.color
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
    var isLiquidGlass: Bool { self == .liquidGlass }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system, .liquidGlass: nil
        case .light: .light
        case .dark, .graphiteDark: .dark
        }
    }

    @MainActor
    func applyToApplication() {
        let appearance: NSAppearance?
        switch self {
        case .system, .liquidGlass:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark, .graphiteDark:
            appearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
            window.isOpaque = !isLiquidGlass
            window.backgroundColor = isLiquidGlass
                ? .clear
                : .windowBackgroundColor
            window.titlebarAppearsTransparent = isLiquidGlass
            window.titlebarSeparatorStyle = isLiquidGlass ? .none : .automatic
            window.invalidateShadow()
            window.contentView?.needsDisplay = true
        }
    }
}

private struct LeafAppearanceModifier: ViewModifier {
    let appearance: LeafAppearance

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance.preferredColorScheme)
            .environment(\.leafAppearance, appearance)
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
