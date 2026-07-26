import Foundation

struct TabSessionRecord: Codable, Equatable {
    let id: UUID
    let url: URL?
    let title: String
    let isPinned: Bool
    let lastActiveAt: Date

    init(id: UUID = UUID(), url: URL?, title: String, isPinned: Bool, lastActiveAt: Date) {
        self.id = id
        self.url = url
        self.title = title
        self.isPinned = isPinned
        self.lastActiveAt = lastActiveAt
    }

    private enum CodingKeys: String, CodingKey { case id, url, title, isPinned, lastActiveAt }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        url = try values.decodeIfPresent(URL.self, forKey: .url)
        title = try values.decode(String.self, forKey: .title)
        isPinned = try values.decode(Bool.self, forKey: .isPinned)
        lastActiveAt = try values.decode(Date.self, forKey: .lastActiveAt)
    }
}

struct BrowserWindowSessionRecord: Codable, Equatable {
    let id: UUID
    let tabIDs: [UUID]
    let workspaceID: UUID?
    let visibleTabIDs: [UUID]
    let focusedTabID: UUID?
    let splitFractions: [Double]
    let frame: CGRect?

    init(id: UUID, tabIDs: [UUID], workspaceID: UUID?, visibleTabIDs: [UUID],
         focusedTabID: UUID?, splitFractions: [Double] = [], frame: CGRect?) {
        self.id = id
        self.tabIDs = tabIDs
        self.workspaceID = workspaceID
        self.visibleTabIDs = visibleTabIDs
        self.focusedTabID = focusedTabID
        self.splitFractions = splitFractions
        self.frame = frame
    }

    private enum CodingKeys: String, CodingKey {
        case id, tabIDs, workspaceID, visibleTabIDs, focusedTabID, splitFractions, frame
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        tabIDs = try values.decode([UUID].self, forKey: .tabIDs)
        workspaceID = try values.decodeIfPresent(UUID.self, forKey: .workspaceID)
        visibleTabIDs = try values.decodeIfPresent([UUID].self, forKey: .visibleTabIDs) ?? []
        focusedTabID = try values.decodeIfPresent(UUID.self, forKey: .focusedTabID)
        splitFractions = try values.decodeIfPresent([Double].self, forKey: .splitFractions) ?? []
        frame = try values.decodeIfPresent(CGRect.self, forKey: .frame)
    }
}

struct BrowserSession: Codable, Equatable {
    let tabs: [TabSessionRecord]
    let selectedIndex: Int
    let windows: [BrowserWindowSessionRecord]
    let activeWindowID: UUID?

    init(tabs: [TabSessionRecord], selectedIndex: Int,
         windows: [BrowserWindowSessionRecord] = [], activeWindowID: UUID? = nil) {
        self.tabs = tabs
        self.selectedIndex = selectedIndex
        self.windows = windows
        self.activeWindowID = activeWindowID
    }

    private enum CodingKeys: String, CodingKey { case tabs, selectedIndex, windows, activeWindowID }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tabs = try values.decode([TabSessionRecord].self, forKey: .tabs)
        selectedIndex = try values.decodeIfPresent(Int.self, forKey: .selectedIndex) ?? 0
        windows = try values.decodeIfPresent([BrowserWindowSessionRecord].self, forKey: .windows) ?? []
        activeWindowID = try values.decodeIfPresent(UUID.self, forKey: .activeWindowID)
    }
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
