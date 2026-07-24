import SwiftUI

private struct CursorHelpModifier: ViewModifier {
    let text: String
    var placement: Alignment
    var animated: Bool

    @State private var isPointerInside = false
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animated && isPointerInside ? 1.06 : 1)
            .brightness(animated && isPointerInside ? 0.08 : 0)
            .shadow(
                color: animated && isPointerInside ? LeafColors.accent.opacity(0.28) : .clear,
                radius: animated && isPointerInside ? 6 : 0
            )
            .animation(.snappy(duration: 0.18), value: isPointerInside)
            .onHover { hovering in
                isPointerInside = hovering
                if hovering {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(180))
                        guard isPointerInside else { return }
                        withAnimation(.snappy(duration: 0.18)) { isPresented = true }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.12)) { isPresented = false }
                }
            }
            .overlay(alignment: placement) {
                if isPresented {
                    Text(text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(.white.opacity(0.14))
                        }
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                        .offset(y: placement == .top ? -38 : 38)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .zIndex(1_000)
                }
            }
            .help(text)
    }
}

extension View {
    func cursorHelp(_ text: String, placement: Alignment = .bottom, animated: Bool = true) -> some View {
        modifier(CursorHelpModifier(text: text, placement: placement, animated: animated))
    }
}
