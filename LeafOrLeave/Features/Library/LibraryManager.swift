import Foundation
import Observation

struct LibraryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let url: URL
    var date: Date
    var visitCount: Int
    var workspaceName: String?

    init(id: UUID, title: String, url: URL, date: Date, visitCount: Int = 1,
         workspaceName: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.date = date
        self.visitCount = max(visitCount, 1)
        self.workspaceName = workspaceName
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, url, date, visitCount, workspaceName
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        url = try values.decode(URL.self, forKey: .url)
        date = try values.decode(Date.self, forKey: .date)
        visitCount = max(try values.decodeIfPresent(Int.self, forKey: .visitCount) ?? 1, 1)
        workspaceName = try values.decodeIfPresent(String.self, forKey: .workspaceName)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(url, forKey: .url)
        try values.encode(date, forKey: .date)
        try values.encode(visitCount, forKey: .visitCount)
        try values.encodeIfPresent(workspaceName, forKey: .workspaceName)
    }
}

@MainActor
@Observable
final class LibraryManager {
    private(set) var bookmarks: [LibraryEntry] = []
    private(set) var history: [LibraryEntry] = []
    private(set) var archivedTabs: [LibraryEntry] = []
    private let defaults: UserDefaults
    private let bookmarksKey = "library.bookmarks.v1"
    private let historyKey = "library.history.v1"
    private let archiveKey = "library.archive.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = Self.load(bookmarksKey, from: defaults)
        history = Self.load(historyKey, from: defaults)
        archivedTabs = Self.load(archiveKey, from: defaults)
    }

    func isBookmarked(_ url: URL?) -> Bool {
        guard let url else { return false }
        return bookmarks.contains { $0.url == url }
    }

    func toggleBookmark(title: String, url: URL?) {
        guard let url, isWebURL(url) else { return }
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.insert(LibraryEntry(id: UUID(), title: cleanTitle(title, url: url), url: url, date: Date()), at: 0)
        }
        save(bookmarks, key: bookmarksKey)
    }

    func recordVisit(title: String, url: URL?, at now: Date = .now) {
        guard let url, isWebURL(url) else { return }
        if let index = history.firstIndex(where: { $0.url == url }) {
            let previous = history[index]
            let isImmediateRepeat = index == 0 && now.timeIntervalSince(previous.date) < 30
            let updated = LibraryEntry(
                id: previous.id,
                title: cleanTitle(title, url: url),
                url: url,
                date: now,
                visitCount: isImmediateRepeat ? previous.visitCount : previous.visitCount + 1
            )
            history.remove(at: index)
            history.insert(updated, at: 0)
        } else {
            history.insert(LibraryEntry(id: UUID(), title: cleanTitle(title, url: url), url: url, date: now), at: 0)
        }
        if history.count > 500 { history.removeLast(history.count - 500) }
        save(history, key: historyKey)
    }

    func autocompleteSuggestion(for input: String) -> String? {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !query.contains(where: { $0.isWhitespace }) else { return nil }

        return history.enumerated().compactMap { index, entry -> (text: String, score: Int)? in
            guard let completion = Self.completionText(for: entry.url, matching: query) else { return nil }
            let recency = max(history.count - index, 0)
            return (completion, entry.visitCount * 10_000 + recency)
        }
        .max { lhs, rhs in
            lhs.score == rhs.score ? lhs.text.count > rhs.text.count : lhs.score < rhs.score
        }?
        .text
    }

    func removeBookmark(_ id: UUID) { bookmarks.removeAll { $0.id == id }; save(bookmarks, key: bookmarksKey) }
    func removeHistory(_ id: UUID) { history.removeAll { $0.id == id }; save(history, key: historyKey) }
    func clearHistory() { history.removeAll(); save(history, key: historyKey) }

    @discardableResult
    func archive(title: String, url: URL?, workspaceName: String?, at now: Date = .now) -> LibraryEntry? {
        guard let url, isWebURL(url) else { return nil }
        let normalizedWorkspace = workspaceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = LibraryEntry(
            id: UUID(),
            title: cleanTitle(title, url: url),
            url: url,
            date: now,
            workspaceName: normalizedWorkspace?.isEmpty == false ? normalizedWorkspace : nil
        )
        archivedTabs.removeAll { $0.url == url }
        archivedTabs.insert(entry, at: 0)
        if archivedTabs.count > 1_000 {
            archivedTabs.removeLast(archivedTabs.count - 1_000)
        }
        save(archivedTabs, key: archiveKey)
        return entry
    }

    func removeArchivedTab(_ id: UUID) {
        archivedTabs.removeAll { $0.id == id }
        save(archivedTabs, key: archiveKey)
    }

    func clearArchive() {
        archivedTabs.removeAll()
        save(archivedTabs, key: archiveKey)
    }

    func restoreCollections(bookmarks importedBookmarks: [LibraryEntry],
                            archivedTabs importedArchive: [LibraryEntry]) {
        bookmarks = Array(importedBookmarks.filter { isWebURL($0.url) }.prefix(5_000))
        archivedTabs = Array(importedArchive.filter { isWebURL($0.url) }.prefix(1_000))
        save(bookmarks, key: bookmarksKey)
        save(archivedTabs, key: archiveKey)
    }

    private func isWebURL(_ url: URL) -> Bool { url.scheme == "http" || url.scheme == "https" }
    private func cleanTitle(_ title: String, url: URL) -> String {
        ["", "Loading…", "New Tab"].contains(title) ? (url.host ?? url.absoluteString) : title
    }

    private static func completionText(for url: URL, matching query: String) -> String? {
        let absolute = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var hostAndPath = url.host ?? absolute
        if hostAndPath.lowercased().hasPrefix("www.") {
            hostAndPath.removeFirst(4)
        }
        if let port = url.port { hostAndPath += ":\(port)" }
        if !url.path.isEmpty, url.path != "/" { hostAndPath += url.path }
        if let query = url.query, !query.isEmpty { hostAndPath += "?\(query)" }
        if let fragment = url.fragment, !fragment.isEmpty { hostAndPath += "#\(fragment)" }

        let candidates = query.localizedCaseInsensitiveContains("://")
            ? [absolute]
            : [hostAndPath, url.host.map { host in
                var value = host
                if let port = url.port { value += ":\(port)" }
                if !url.path.isEmpty, url.path != "/" { value += url.path }
                return value
            }, absolute].compactMap { $0 }

        return candidates.first { candidate in
            candidate.count > query.count && candidate.lowercased().hasPrefix(query.lowercased())
        }
    }
    private func save(_ entries: [LibraryEntry], key: String) {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
    private static func load(_ key: String, from defaults: UserDefaults) -> [LibraryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LibraryEntry].self, from: data)) ?? []
    }
}
