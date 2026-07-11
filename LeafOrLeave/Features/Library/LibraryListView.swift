import SwiftUI

enum LibraryListKind { case bookmarks, history }

struct LibraryListView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: LibraryManager
    let kind: LibraryListKind
    let open: (URL) -> Void
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filtered.isEmpty { emptyState } else { list }
        }
        .frame(minWidth: 600, idealWidth: 680, minHeight: 440, idealHeight: 540)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: kind == .bookmarks ? "bookmark.fill" : "clock.fill")
                .font(.system(size: 18)).foregroundStyle(LeafColors.accent)
            Text(kind == .bookmarks ? "Bookmarks" : "History").font(.headline)
            TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
            Spacer()
            if kind == .history, !manager.history.isEmpty {
                Button("Clear History", role: .destructive) { manager.clearHistory() }
            }
            Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                .buttonStyle(.plain).background(.white.opacity(0.07), in: Circle()).help("Close")
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var list: some View {
        List(filtered) { entry in
            HStack(spacing: 12) {
                Image(systemName: "globe").foregroundStyle(.secondary).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(entry.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if kind == .history { Text(entry.date, style: .relative).font(.caption).foregroundStyle(.tertiary) }
                Button("Open") { open(entry.url); dismiss() }.buttonStyle(.bordered)
                Button(role: .destructive) { remove(entry.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
            .padding(.vertical, 5)
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        ContentUnavailableView(search.isEmpty ? (kind == .bookmarks ? "No Bookmarks" : "No History") : "No Results",
                               systemImage: kind == .bookmarks ? "bookmark" : "clock",
                               description: Text(search.isEmpty ? (kind == .bookmarks ? "Bookmark a page using the star in the toolbar." : "Pages you visit will appear here.") : "Try another search term."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entries: [LibraryEntry] { kind == .bookmarks ? manager.bookmarks : manager.history }
    private var filtered: [LibraryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.url.absoluteString.localizedCaseInsensitiveContains(search) }
    }
    private func remove(_ id: UUID) { kind == .bookmarks ? manager.removeBookmark(id) : manager.removeHistory(id) }
}
