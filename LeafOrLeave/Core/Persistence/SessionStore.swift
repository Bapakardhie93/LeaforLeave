import Foundation

struct TabSessionRecord: Codable, Equatable {
    let url: URL?
    let title: String
    let isPinned: Bool
    let lastActiveAt: Date
}

struct BrowserSession: Codable, Equatable {
    let tabs: [TabSessionRecord]
    let selectedIndex: Int
}

struct SessionStore {
    private let defaults: UserDefaults
    private let key = "browser.session.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> BrowserSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BrowserSession.self, from: data)
    }

    func save(_ session: BrowserSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key)
    }
}
