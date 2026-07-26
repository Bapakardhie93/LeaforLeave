import SwiftUI

extension View {
    /// Uses the native macOS help tag so the tooltip is hosted by the window,
    /// stays above adjacent chrome, and is never clipped by a SwiftUI layout.
    func cursorHelp(
        _ text: String,
        placement: Alignment = .bottom,
        animated: Bool = false
    ) -> some View {
        help(text)
    }
}
