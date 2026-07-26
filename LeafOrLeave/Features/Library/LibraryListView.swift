import AppKit
import SwiftUI

enum LibraryListKind { case bookmarks, history }

struct LibraryListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.leafAccentColor) private var accentColor
    let manager: LibraryManager
    let kind: LibraryListKind
    let open: (URL) -> Void
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            content
        }
        .frame(minWidth: 660, idealWidth: 740, minHeight: 480, idealHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.snappy(duration: 0.22), value: filtered.count)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: kind == .bookmarks ? "bookmark.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .shadow(color: accentColor.opacity(0.2), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if kind == .history, !manager.history.isEmpty {
                Menu {
                    Button("Clear All History", systemImage: "trash", role: .destructive) {
                        manager.clearHistory()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 27, height: 27)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("History actions")
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close \(title)")
            .accessibilityLabel("Close \(title)")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 15)
        .background {
            LinearGradient(
                colors: [accentColor.opacity(0.065), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(searchPrompt, text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: 310)
            .frame(height: 34)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.primary.opacity(0.065))
                    .allowsHitTesting(false)
            }

            Spacer()

            Label(countLabel, systemImage: kind == .bookmarks ? "bookmark" : "clock")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.primary.opacity(0.035), in: Capsule())
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            libraryList
        }
    }

    private var libraryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(group.title.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(0.75)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(group.entries) { entry in
                                LibraryEntryRow(
                                    entry: entry,
                                    kind: kind,
                                    open: { open(entry.url); dismiss() },
                                    remove: { remove(entry.id) }
                                )
                                if entry.id != group.entries.last?.id {
                                    Divider().padding(.leading, 64)
                                }
                            }
                        }
                        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.055))
                                .allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .scrollIndicators(.automatic)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(accentColor.opacity(0.1))
                Circle().strokeBorder(accentColor.opacity(0.16))
                Image(systemName: search.isEmpty ? emptyIcon : "magnifyingglass")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 72, height: 72)

            Text(emptyTitle)
                .font(.title3.weight(.semibold))
            Text(emptyDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if !search.isEmpty {
                Button("Clear Search") { search = "" }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var entries: [LibraryEntry] {
        kind == .bookmarks ? manager.bookmarks : manager.history
    }

    private var filtered: [LibraryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.url.absoluteString.localizedCaseInsensitiveContains(search)
        }
    }

    private var groups: [LibraryDateGroup] {
        guard kind == .history else {
            return [LibraryDateGroup(title: "Saved pages", entries: filtered)]
        }
        var result: [LibraryDateGroup] = []
        for entry in filtered {
            let groupTitle = dateGroupTitle(entry.date)
            if result.last?.title == groupTitle {
                result[result.count - 1].entries.append(entry)
            } else {
                result.append(LibraryDateGroup(title: groupTitle, entries: [entry]))
            }
        }
        return result
    }

    private var title: String { kind == .bookmarks ? "Bookmarks" : "History" }
    private var searchPrompt: String { "Search \(title.lowercased())" }
    private var countLabel: String { "\(filtered.count) \(filtered.count == 1 ? "item" : "items")" }
    private var emptyIcon: String { kind == .bookmarks ? "bookmark" : "clock.arrow.circlepath" }
    private var emptyTitle: String {
        if !search.isEmpty { return "No matching results" }
        return kind == .bookmarks ? "No bookmarks yet" : "No browsing history"
    }
    private var emptyDetail: String {
        if !search.isEmpty { return "Try a different page title, website, or address." }
        return kind == .bookmarks
            ? "Save useful pages with the bookmark button and they will stay within easy reach."
            : "Pages you visit outside Private Browsing will appear here automatically."
    }
    private var summary: String {
        if entries.isEmpty { return kind == .bookmarks ? "Keep useful pages close" : "Your recent browsing activity" }
        if kind == .bookmarks {
            return "\(entries.count) saved page\(entries.count == 1 ? "" : "s")"
        }
        let visits = entries.reduce(0) { $0 + $1.visitCount }
        return "\(visits) visit\(visits == 1 ? "" : "s") across \(entries.count) page\(entries.count == 1 ? "" : "s")"
    }

    private func dateGroupTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func remove(_ id: UUID) {
        kind == .bookmarks ? manager.removeBookmark(id) : manager.removeHistory(id)
    }
}

private struct LibraryDateGroup: Identifiable {
    let title: String
    var entries: [LibraryEntry]
    var id: String { title }
}

private struct LibraryEntryRow: View {
    @Environment(\.leafAccentColor) private var accentColor
    let entry: LibraryEntry
    let kind: LibraryListKind
    let open: () -> Void
    let remove: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: entry.url.scheme == "https" ? "globe.americas.fill" : "globe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .frame(width: 38, height: 38)
                    .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if entry.url.scheme == "https" {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 13, height: 13)
                        .background(LeafColors.secure, in: Circle())
                        .overlay { Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5) }
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(displayHost)
                    if pathDetail != nil { Text("•") }
                    if let pathDetail {
                        Text(pathDetail).lineLimit(1).truncationMode(.middle)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if kind == .history {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(entry.date, style: .relative)
                    Text(entry.visitCount == 1 ? "1 visit" : "\(entry.visitCount) visits")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            } else {
                Text("Saved \(entry.date.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            Menu {
                Button("Open Page", systemImage: "arrow.up.forward.app", action: open)
                Button("Copy Address", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
                }
                Divider()
                Button(kind == .bookmarks ? "Remove Bookmark" : "Remove from History",
                       systemImage: "trash", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 25, height: 21)
                    .background(Color.primary.opacity(hovered ? 0.065 : 0.035), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More actions")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(hovered ? 0.045 : 0))
        .contentShape(Rectangle())
        .onHover { value in
            withAnimation(.easeOut(duration: 0.14)) { hovered = value }
        }
        .onTapGesture(count: 2, perform: open)
        .contextMenu {
            Button("Open Page", action: open)
            Button("Copy Address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
            }
            Divider()
            Button(kind == .bookmarks ? "Remove Bookmark" : "Remove from History",
                   role: .destructive, action: remove)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(displayHost)")
    }

    private var displayHost: String {
        guard var host = entry.url.host else { return entry.url.absoluteString }
        if host.lowercased().hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    private var pathDetail: String? {
        let value = entry.url.path
        return value.isEmpty || value == "/" ? nil : value
    }
}
