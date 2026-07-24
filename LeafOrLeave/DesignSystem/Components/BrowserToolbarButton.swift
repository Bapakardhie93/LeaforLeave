import SwiftUI

struct BrowserToolbarButton: View {
    let systemName: String
    let helpText: String
    var isEnabled = true
    var drawsBackground = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .cursorHelp(helpText)
        .accessibilityLabel(helpText)
    }

    private var backgroundColor: Color {
        guard isEnabled else { return drawsBackground ? LeafColors.chromeSurface.opacity(0.45) : .clear }
        if isHovered { return LeafColors.chromeHover }
        return drawsBackground ? LeafColors.chromeSurface : .clear
    }
}
