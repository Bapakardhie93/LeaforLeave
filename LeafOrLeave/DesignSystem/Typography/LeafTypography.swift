import SwiftUI

/// Shared type tokens keep hierarchy and density consistent across browser
/// chrome, settings, sidebars, cards, and diagnostic surfaces.
enum LeafTypography {
    static let navigationTitle = Font.system(size: 27, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 14, weight: .semibold)
    static let bodyEmphasized = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13, weight: .medium)
    static let supporting = Font.system(size: 11, weight: .regular)
    static let caption = Font.system(size: 10.5, weight: .regular)
    static let sectionLabel = Font.system(size: 10, weight: .semibold)
    static let metric = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
}
