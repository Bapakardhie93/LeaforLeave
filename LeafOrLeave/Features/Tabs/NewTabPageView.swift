import SwiftUI

struct NewTabPageView: View {
    @State private var query = ""
    let submit: (String) -> Void

    private let links = [("graduationcap.fill", "LMS", "https://classroom.google.com"), ("chevron.left.forwardslash.chevron.right", "GitHub", "https://github.com"), ("sparkles", "ChatGPT", "https://chatgpt.com"), ("play.rectangle.fill", "YouTube", "https://youtube.com"), ("music.note", "Spotify", "https://open.spotify.com")]

    var body: some View {
        ZStack {
            LeafColors.background.ignoresSafeArea()
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill").font(.system(size: 38)).foregroundStyle(LeafColors.accent)
                    Text("LeafOrLeave").font(.system(size: 28, weight: .semibold))
                }
                TextField("Search or enter a website", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 15)).padding(.horizontal, 18).frame(width: 520, height: 46)
                    .background(LeafColors.omnibox, in: RoundedRectangle(cornerRadius: 13))
                    .overlay { RoundedRectangle(cornerRadius: 13).stroke(LeafColors.border) }
                    .onSubmit { submit(query) }
                HStack(spacing: 12) {
                    ForEach(links, id: \.1) { link in
                        Button { submit(link.2) } label: {
                            VStack(spacing: 8) { Image(systemName: link.0).font(.title3); Text(link.1).font(.caption) }
                                .frame(width: 78, height: 66).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                HStack(spacing: 24) {
                    Label("Study workspace", systemImage: "books.vertical")
                    Label("Network ready", systemImage: "wifi")
                    Label("Exam Protection off", systemImage: "shield")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
