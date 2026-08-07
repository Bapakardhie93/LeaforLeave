import AppKit
import SwiftUI

struct LeafApplicationIcon: View {
    var size: CGFloat = 40

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.16), radius: size * 0.16, y: size * 0.07)
            .accessibilityHidden(true)
    }
}
