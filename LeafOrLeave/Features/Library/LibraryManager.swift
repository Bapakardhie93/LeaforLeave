import Foundation
import Observation

struct LibraryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let url: URL
    var date: Date
}

@MainActor
@Observable
final class LibraryManager {
    private(set) var bookmarks: [LibraryEntry] = []
    private(set) var history: [LibraryEntry] = []
    private let defaults: UserDefaults
    private let bookmarksKey = "library.bookmarks.v1"
    private let historyKey = "library.history.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bookmarks = Self.load(bookmarksKey, from: defaults)
        history = Self.load(historyKey, from: defaults)
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

    func recordVisit(title: String, url: URL?) {
        guard let url, isWebURL(url) else { return }
        let now = Date()
        if let first = history.first, first.url == url, now.timeIntervalSince(first.date) < 30 {
            history[0].title = cleanTitle(title, url: url)
            history[0].date = now
        } else {
            history.removeAll { $0.url == url }
            history.insert(LibraryEntry(id: UUID(), title: cleanTitle(title, url: url), url: url, date: now), at: 0)
        }
        if history.count > 500 { history.removeLast(history.count - 500) }
        save(history, key: historyKey)
    }

    func removeBookmark(_ id: UUID) { bookmarks.removeAll { $0.id == id }; save(bookmarks, key: bookmarksKey) }
    func removeHistory(_ id: UUID) { history.removeAll { $0.id == id }; save(history, key: historyKey) }
    func clearHistory() { history.removeAll(); save(history, key: historyKey) }

    private func isWebURL(_ url: URL) -> Bool { url.scheme == "http" || url.scheme == "https" }
    private func cleanTitle(_ title: String, url: URL) -> String {
        ["", "Loading…", "New Tab"].contains(title) ? (url.host ?? url.absoluteString) : title
    }
    private func save(_ entries: [LibraryEntry], key: String) {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
    private static func load(_ key: String, from defaults: UserDefaults) -> [LibraryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LibraryEntry].self, from: data)) ?? []
    }
}
