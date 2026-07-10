import SwiftUI

struct LeafTheme {
    let background, surface, elevatedSurface, border, primaryText, secondaryText, accent, success, warning, critical, mediaActive: Color
    static func theme(for appearance: LeafAppearance) -> LeafTheme {
        let light = appearance == .light
        return .init(background: light ? .white : Color(nsColor: .windowBackgroundColor), surface: light ? Color.black.opacity(0.04) : Color.white.opacity(0.06), elevatedSurface: light ? .white : Color(white: 0.12), border: light ? Color.black.opacity(0.12) : Color.white.opacity(0.1), primaryText: light ? .black : .white, secondaryText: .secondary, accent: LeafColors.accent, success: .green, warning: .orange, critical: .red, mediaActive: .pink)
    }
}
