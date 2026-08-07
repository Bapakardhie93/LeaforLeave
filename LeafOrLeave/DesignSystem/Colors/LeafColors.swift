import SwiftUI

enum LeafColors {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let liquidGlassBackground = Color(nsColor: .windowBackgroundColor).opacity(0.85)
    static let omnibox = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let border = Color.primary.opacity(0.11)
    static let chromeSurface = Color.primary.opacity(0.055)
    static let chromeHover = Color.primary.opacity(0.095)
    static let chromeSelected = Color.primary.opacity(0.135)
    static let accent = Color(red: 0.58, green: 0.39, blue: 0.96)
    static let secure = Color(red: 0.32, green: 0.78, blue: 0.52)
}
