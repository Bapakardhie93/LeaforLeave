import AppKit
import SwiftUI

enum LibraryListKind { case bookmarks, history, archive }

struct LibraryListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.leafAccentColor) private var accentColor
    @Environment(\.leafAppearance) private var appearance
    let manager: LibraryManager
    let kind: LibraryListKind
    let open: (URL) -> Void
    @State private var search = ""

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 0) {
                header
                controls
                content
            }
        }
        .frame(minWidth: 700, idealWidth: 780, minHeight: 520, idealHeight: 640)
        .animation(.snappy(duration: 0.22), value: filtered.count)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if appearance.isLiquidGlass {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(nsColor: .windowBackgroundColor).opacity(0.20)
                RadialGradient(
                    colors: [accentColor.opacity(0.09), .clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 420
                )
            }
        } else {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [accentColor.opacity(0.045), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: headerIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: accentColor.opacity(0.24), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if kind != .bookmarks, !entries.isEmpty {
                Menu {
                    Button(clearAllTitle, systemImage: "trash", role: .destructive) {
                        clearAll()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 27, height: 27)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                    .help("\(title) actions")
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
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 18)
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
            .frame(maxWidth: 330)
            .frame(height: 36)
            .background(controlSurface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.065))
                    .allowsHitTesting(false)
            }

            Spacer()

            Label(countLabel, systemImage: countIcon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.primary.opacity(0.035), in: Capsule())
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
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
            LazyVStack(alignment: .leading, spacing: 21) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            Text(group.title)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.primary.opacity(0.09), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 3)

                        VStack(spacing: 8) {
                            ForEach(group.entries) { entry in
                                LibraryEntryRow(
                                    entry: entry,
                                    kind: kind,
                                    open: { open(entry.url); dismiss() },
                                    remove: { remove(entry.id) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
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
        switch kind {
        case .bookmarks: manager.bookmarks
        case .history: manager.history
        case .archive: manager.archivedTabs
        }
    }

    private var filtered: [LibraryEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.url.absoluteString.localizedCaseInsensitiveContains(search)
        }
    }

    private var groups: [LibraryDateGroup] {
        guard kind != .bookmarks else {
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

    private var title: String {
        switch kind {
        case .bookmarks: "Bookmarks"
        case .history: "History"
        case .archive: "Archive"
        }
    }
    private var searchPrompt: String { "Search \(title.lowercased())" }
    private var countLabel: String { "\(filtered.count) \(filtered.count == 1 ? "item" : "items")" }
    private var headerIcon: String {
        switch kind {
        case .bookmarks: "bookmark.fill"
        case .history: "clock.arrow.circlepath"
        case .archive: "archivebox.fill"
        }
    }
    private var countIcon: String {
        switch kind {
        case .bookmarks: "bookmark"
        case .history: "clock"
        case .archive: "archivebox"
        }
    }
    private var emptyIcon: String { countIcon }
    private var emptyTitle: String {
        if !search.isEmpty { return "No matching results" }
        switch kind {
        case .bookmarks: return "No bookmarks yet"
        case .history: return "No browsing history"
        case .archive: return "No archived tabs"
        }
    }
    private var emptyDetail: String {
        if !search.isEmpty { return "Try a different page title, website, or address." }
        switch kind {
        case .bookmarks:
            return "Save useful pages with the bookmark button and they will stay within easy reach."
        case .history:
            return "Pages you visit outside Private Browsing will appear here automatically."
        case .archive:
            return "Archive tabs you may need later without leaving them open in your workspace."
        }
    }
    private var summary: String {
        if entries.isEmpty {
            switch kind {
            case .bookmarks: return "Keep useful pages close"
            case .history: return "Your recent browsing activity"
            case .archive: return "Keep the useful, leave the clutter"
            }
        }
        if kind == .bookmarks {
            return "\(entries.count) saved page\(entries.count == 1 ? "" : "s")"
        }
        if kind == .archive {
            return "\(entries.count) tab\(entries.count == 1 ? "" : "s") set aside for later"
        }
        let visits = entries.reduce(0) { $0 + $1.visitCount }
        return "\(visits) visit\(visits == 1 ? "" : "s") across \(entries.count) page\(entries.count == 1 ? "" : "s")"
    }

    private var controlSurface: Color {
        Color.primary.opacity(appearance.isLiquidGlass ? 0.075 : 0.04)
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
        switch kind {
        case .bookmarks: manager.removeBookmark(id)
        case .history: manager.removeHistory(id)
        case .archive: manager.removeArchivedTab(id)
        }
    }

    private var clearAllTitle: String {
        kind == .archive ? "Clear Archive" : "Clear All History"
    }

    private func clearAll() {
        if kind == .archive { manager.clearArchive() }
        else { manager.clearHistory() }
    }
}

private struct LibraryDateGroup: Identifiable {
    let title: String
    var entries: [LibraryEntry]
    var id: String { title }
}

private struct LibraryEntryRow: View {
    @Environment(\.leafAccentColor) private var accentColor
    @Environment(\.leafAppearance) private var appearance
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
                    .frame(width: 42, height: 42)
                    .background(accentColor.opacity(0.11), in: Circle())

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
            .frame(width: 44, height: 44)

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
            } else if kind == .archive {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Archived \(entry.date.formatted(.relative(presentation: .named)))")
                    if let workspaceName = entry.workspaceName {
                        Text(workspaceName).foregroundStyle(.tertiary)
                    }
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
                Button(removeTitle,
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
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    appearance.isLiquidGlass
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(Color.primary.opacity(hovered ? 0.055 : 0.028))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(hovered ? 0.12 : 0.06))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(hovered ? 0.09 : 0.025), radius: hovered ? 12 : 5, y: hovered ? 5 : 2)
        .scaleEffect(hovered ? 1.003 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            Button(removeTitle,
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

    private var removeTitle: String {
        switch kind {
        case .bookmarks: "Remove Bookmark"
        case .history: "Remove from History"
        case .archive: "Remove from Archive"
        }
    }
}
