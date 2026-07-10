import Foundation
import Observation
import SwiftUI
import WebKit

@MainActor
@Observable
final class TabManager {
    private(set) var tabs: [BrowserTab] = []
    var selectedTabID: UUID?
    weak var downloadManager: DownloadManager?

    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }
    private let webViewFactory: WebViewFactory
    private let sessionStore: SessionStore
    private let resolver = URLResolver()
    private var closedTabs: [TabSessionRecord] = []
    private var saveTask: Task<Void, Never>?

    init(webViewFactory: WebViewFactory, sessionStore: SessionStore) {
        self.webViewFactory = webViewFactory
        self.sessionStore = sessionStore
        restoreSession()
    }

    @discardableResult
    func createTab(opening url: URL? = nil, activate: Bool = true,
                   configuration: WKWebViewConfiguration? = nil) -> BrowserTab {
        let webView = configuration.map(webViewFactory.makeWebView(configuration:)) ?? webViewFactory.makeWebView()
        let tab = BrowserTab(webView: webView, url: url)
        tab.manager = self
        tabs.append(tab)
        if activate { selectTab(id: tab.id) }
        if let url { tab.load(url) }
        saveSession()
        return tab
    }

    func closeSelectedTab() { if let selectedTabID { closeTab(id: selectedTabID) } }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        if tab.isExamProtected {
            let alert = NSAlert(); alert.messageText = "Close protected tab?"
            alert.informativeText = "Unsaved exam answers may be lost."
            alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Close Anyway")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        closedTabs.append(TabSessionRecord(url: tab.url, title: tab.title, isPinned: tab.isPinned, lastActiveAt: tab.lastActiveAt))
        if closedTabs.count > 20 { closedTabs.removeFirst() }
        tab.tearDown()
        tabs.remove(at: index)
        if selectedTabID == id {
            selectedTabID = tabs.indices.contains(index - 1) ? tabs[index - 1].id : tabs.first?.id
        }
        if tabs.isEmpty { createTab() } else { updateLifecycleStates() }
        saveSession()
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
        selectedTab?.restoreIfNeeded()
        selectedTab?.lastActiveAt = Date()
        updateLifecycleStates()
        saveSession()
    }

    func selectRelative(_ offset: Int) {
        guard !tabs.isEmpty, let id = selectedTabID, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectTab(id: tabs[(index + offset + tabs.count) % tabs.count].id)
    }

    func selectTab(number: Int) {
        guard !tabs.isEmpty else { return }
        let index = number == 9 ? tabs.count - 1 : number - 1
        guard tabs.indices.contains(index) else { return }
        selectTab(id: tabs[index].id)
    }

    func duplicateTab(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        createTab(opening: tab.url)
    }

    func reopenLastClosedTab() {
        guard let record = closedTabs.popLast() else { return }
        let tab = createTab(opening: record.url)
        tab.isPinned = record.isPinned
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        saveSession()
    }

    func moveTab(id: UUID, by offset: Int) {
        guard let source = tabs.firstIndex(where: { $0.id == id }) else { return }
        let destination = min(max(source + offset, 0), tabs.count - 1)
        guard source != destination else { return }
        let tab = tabs.remove(at: source)
        tabs.insert(tab, at: destination)
        saveSession()
    }

    func togglePin(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.isPinned.toggle()
        tabs.sort { $0.isPinned && !$1.isPinned }
        saveSession()
    }

    func handlePopup(request: URLRequest, configuration: WKWebViewConfiguration) -> WKWebView? {
        let tab = createTab(activate: true, configuration: configuration)
        tab.webView.load(request)
        return tab.webView
    }

    func navigateSelected(to input: String) -> Bool {
        guard let url = resolver.resolve(input), let tab = selectedTab else { return false }
        tab.navigationError = nil
        tab.load(url)
        return true
    }

    func tabDidChange(_ tab: BrowserTab) { if tab.url != nil { scheduleSave() } }

    private func updateLifecycleStates() {
        for tab in tabs { tab.lifecycleState = tab.id == selectedTabID ? .active : .background }
    }

    private func restoreSession() {
        guard let session = sessionStore.load(), !session.tabs.isEmpty else { createTab(); return }
        for record in session.tabs {
            let tab = createTab(opening: record.url, activate: false)
            tab.title = record.title
            tab.isPinned = record.isPinned
            tab.lastActiveAt = record.lastActiveAt
        }
        selectedTabID = tabs[min(max(session.selectedIndex, 0), tabs.count - 1)].id
        updateLifecycleStates()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveSession()
        }
    }

    func saveSession() {
        guard !tabs.isEmpty else { return }
        let selectedIndex = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        let records = tabs.map { TabSessionRecord(url: $0.url, title: $0.title, isPinned: $0.isPinned, lastActiveAt: $0.lastActiveAt) }
        sessionStore.save(BrowserSession(tabs: records, selectedIndex: selectedIndex))
    }
}
