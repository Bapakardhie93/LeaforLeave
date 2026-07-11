import SwiftUI

struct FindBarView: View {
    @Binding var text: String
    let result: String
    let previous: () -> Void
    let next: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find on page", text: $text).textFieldStyle(.plain).frame(width: 190).onSubmit(next)
            Text(result).font(.caption).foregroundStyle(.secondary).frame(minWidth: 42)
            Button(action: previous) { Image(systemName: "chevron.up") }.help("Previous")
            Button(action: next) { Image(systemName: "chevron.down") }.help("Next")
            Button(action: close) { Image(systemName: "xmark") }.help("Close")
        }
        .buttonStyle(.plain).padding(.horizontal, 12).frame(height: 38)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
    }
}
