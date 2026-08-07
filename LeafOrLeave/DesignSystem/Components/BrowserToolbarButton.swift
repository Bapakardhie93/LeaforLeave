import SwiftUI

struct BrowserToolbarButton: View {
    @Environment(\.leafToolbarIconSize) private var toolbarIconSize
    let systemName: String
    let helpText: String
    var isEnabled = true
    var drawsBackground = false
    var iconScale: CGFloat = 1
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                Image(systemName: systemName)
                    .font(.system(size: toolbarIconSize * iconScale, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.toolbarControlCornerRadius, style: .continuous))
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
