import SwiftUI

struct BrowserToolbarButton: View {
    let systemName: String
    let helpText: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
        .background(Color.white.opacity(isEnabled ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 8))
        .disabled(!isEnabled)
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}
