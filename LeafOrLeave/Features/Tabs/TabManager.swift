import AppKit
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
@Observable
final class TabManager {
    private(set) var tabs: [BrowserTab] = []
    private(set) var windows: [BrowserWindowState] = []
    private(set) var activeWindowID: UUID?
    var draggedTabID: UUID?
    var dragSourceWindowID: UUID?
    var dragTargetWindowID: UUID?
    private var dragSourceIndex: Int?
    weak var downloadManager: DownloadManager?
    weak var libraryManager: LibraryManager?
    weak var workspaceManager: WorkspaceManager?
    weak var settings: SettingsStore?
    weak var passwordVault: PasswordVault?

    var activeWindow: BrowserWindowState? {
        windows.first { $0.id == activeWindowID } ?? windows.first
    }
    var selectedTabID: UUID? { activeWindow?.focusedTabID }
    var selectedTab: BrowserTab? { tab(id: selectedTabID) }
    var visibleTabIDs: Set<UUID> { Set(windows.flatMap(\.visibleTabIDs)) }
    var initialWindowID: UUID {
        if let id = activeWindow?.id { return id }
        let state = createFallbackWindow()
        createTab(in: state.id)
        return state.id
    }

    private let webViewFactory: WebViewFactory
    private let sessionStore: SessionStore
    private let resolver = URLResolver()
    private var closedTabs: [TabSessionRecord] = []
    private var saveTask: Task<Void, Never>?
    private var saveRevision = 0
    private var didRequestRestoredWindows = false

    init(webViewFactory: WebViewFactory, sessionStore: SessionStore,
         restoresPreviousSession: Bool = true) {
        self.webViewFactory = webViewFactory
        self.sessionStore = sessionStore
        if restoresPreviousSession {
            restoreSession()
        } else {
            let window = BrowserWindowState()
            windows = [window]
            activeWindowID = window.id
            createTab(in: window.id)
        }
    }

    func window(id: UUID) -> BrowserWindowState? { windows.first { $0.id == id } }
    func tab(id: UUID?) -> BrowserTab? {
        guard let id else { return nil }
        return tabs.first { $0.id == id }
    }
    func tabs(in windowID: UUID) -> [BrowserTab] {
        guard let window = window(id: windowID) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        return window.tabIDs.compactMap { byID[$0] }
    }
    func ownerWindow(of tabID: UUID) -> BrowserWindowState? {
        windows.first { $0.tabIDs.contains(tabID) }
    }

    func activateWindow(id: UUID) {
        guard let state = window(id: id) else { return }
        activeWindowID = state.id
        state.focusedTabID.flatMap(tab(id:))?.restoreIfNeeded()
        updateLifecycleStates()
    }

    func restoredWindowIDs(excluding currentID: UUID) -> [UUID] {
        guard !didRequestRestoredWindows else { return [] }
        didRequestRestoredWindows = true
        return windows.map(\.id).filter { $0 != currentID }
    }

    @discardableResult
    func createWindow(moving tabID: UUID? = nil, workspaceID: UUID? = nil) -> BrowserWindowState {
        let state = BrowserWindowState(workspaceID: workspaceID)
        windows.append(state)
        if let tabID, tab(id: tabID) != nil {
            moveTab(tabID, toWindow: state.id, activate: true)
        } else {
            createTab(in: state.id)
        }
        activeWindowID = state.id
        saveSession()
        return state
    }

    func closeWindow(id: UUID, closingTabs: Bool = true) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let state = windows[index]
        if closingTabs {
            for tabID in state.tabIDs {
                tab(id: tabID)?.tearDown()
                tabs.removeAll { $0.id == tabID }
            }
        }
        windows.remove(at: index)
        if activeWindowID == id { activeWindowID = windows.first?.id }
        updateLifecycleStates()
        saveSession()
    }

    func updateWindowFrame(id: UUID, frame: CGRect) {
        guard let window = window(id: id), window.frame != frame else { return }
        window.frame = frame
        scheduleSave()
    }

    @discardableResult
    func createTab(opening url: URL? = nil, activate: Bool = true,
                   configuration: WKWebViewConfiguration? = nil,
                   in windowID: UUID? = nil, isPrivate: Bool = false) -> BrowserTab {
        let destination = windowID.flatMap(window(id:)) ?? activeWindow ?? createFallbackWindow()
        let webView: WKWebView
        if let configuration {
            // Popup configurations are supplied by WebKit and preserve the
            // opener relationship as well as the source tab's data store.
            // Some websites hand us a configuration whose content controller
            // already contains the opener's LeafOrLeave message handlers.
            // BrowserTab installs its own handlers, so give the popup an empty
            // controller to avoid duplicate-name NSInvalidArgumentException
            // faults and callbacks being delivered to the source tab.
            configuration.userContentController = WKUserContentController()
            webView = webViewFactory.makeWebView(configuration: configuration)
        } else if isPrivate {
            webView = webViewFactory.makePrivateWebView()
        } else {
            webView = webViewFactory.makeWebView()
        }
        let tab = BrowserTab(webView: webView, url: url, isPrivate: isPrivate)
        tab.webView.isInspectable = settings?.value.developerMode == true && settings?.value.webInspector == true
        tab.manager = self
        tabs.append(tab)
        destination.insertTab(tab.id, activate: activate)
        if activate { activeWindowID = destination.id }
        if let url { tab.load(url) }
        updateLifecycleStates()
        saveSession()
        return tab
    }

    @discardableResult
    func createPrivateTab(opening url: URL? = nil, in windowID: UUID? = nil) -> BrowserTab {
        createTab(opening: url, in: windowID, isPrivate: true)
    }

    func closeSelectedTab() {
        if let selectedTabID { closeTab(id: selectedTabID) }
    }

    func closeTab(id: UUID, addingToRecentlyClosed: Bool = true) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        if tab.isExamProtected {
            let alert = NSAlert()
            alert.messageText = "Close protected tab?"
            alert.informativeText = "Unsaved exam answers may be lost."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Close Anyway")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        if addingToRecentlyClosed, !tab.isPrivate {
            closedTabs.append(TabSessionRecord(id: tab.id, url: tab.url, title: tab.title,
                                               isPinned: tab.isPinned, lastActiveAt: tab.lastActiveAt))
            if closedTabs.count > 20 { closedTabs.removeFirst() }
        }
        let owner = ownerWindow(of: id)
        owner?.removeTab(id)
        tab.tearDown()
        tabs.remove(at: index)

        if let owner, owner.tabIDs.isEmpty, windows.count == 1 {
            createTab(in: owner.id)
        } else {
            updateLifecycleStates()
            saveSession()
        }
    }

    /// Keeps a tab in the active context by pinning it in both the window and
    /// its workspace. This is the durable "Keep" side of LeafOrLeave's core
    /// decision flow.
    func keepTab(id: UUID) {
        guard let tab = tab(id: id) else { return }
        tab.isPinned = true
        if let workspaceID = ownerWindow(of: id)?.workspaceID {
            workspaceManager?.pinTab(id, in: workspaceID)
        }
        saveSession()
    }

    /// Saves a restorable reference and removes the live WebKit tab. Private,
    /// internal, and blank pages deliberately cannot enter the archive.
    @discardableResult
    func archiveTab(id: UUID) -> Bool {
        guard let tab = tab(id: id), !tab.isPrivate, !tab.isExamProtected, let url = tab.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        let workspaceID = ownerWindow(of: id)?.workspaceID
        let workspaceName = workspaceID.flatMap { id in
            workspaceManager?.workspaces.first { $0.id == id }?.name
        }
        guard libraryManager?.archive(
            title: tab.title,
            url: url,
            workspaceName: workspaceName
        ) != nil else { return false }
        closeTab(id: id, addingToRecentlyClosed: false)
        LeafLog.notice("Tab archived and closed", category: .browser)
        return true
    }

    func leaveTab(id: UUID) {
        closeTab(id: id)
    }

    func selectTab(id: UUID, in windowID: UUID? = nil) {
        guard tab(id: id) != nil else { return }
        let destination = windowID.flatMap(window(id:)) ?? ownerWindow(of: id) ?? activeWindow
        guard let destination, destination.tabIDs.contains(id) else { return }
        guard destination.focusedTabID != id || activeWindowID != destination.id else { return }
        destination.select(id)
        activeWindowID = destination.id
        tab(id: id)?.restoreIfNeeded()
        tab(id: id)?.lastActiveAt = Date()
        updateLifecycleStates()
        scheduleSave()
    }

    func focusTab(id: UUID, in windowID: UUID) {
        guard let state = window(id: windowID), state.visibleTabIDs.contains(id) else { return }
        guard state.focusedTabID != id || activeWindowID != windowID else { return }
        state.focusedTabID = id
        activeWindowID = windowID
        tab(id: id)?.restoreIfNeeded()
        tab(id: id)?.lastActiveAt = Date()
        updateLifecycleStates()
        scheduleSave()
    }

    @discardableResult
    func addToSplit(tabID: UUID, in windowID: UUID) -> Bool {
        guard let state = window(id: windowID), state.tabIDs.contains(tabID),
              state.addSplit(tabID) else { return false }
        activeWindowID = windowID
        tab(id: tabID)?.restoreIfNeeded()
        updateLifecycleStates()
        scheduleSave()
        return true
    }

    func removeFromSplit(tabID: UUID, in windowID: UUID) {
        guard let state = window(id: windowID) else { return }
        state.removeSplit(tabID)
        updateLifecycleStates()
        scheduleSave()
    }

    func exitSplit(in windowID: UUID) {
        window(id: windowID)?.exitSplit()
        updateLifecycleStates()
        scheduleSave()
    }

    func commitSplitFractions(_ values: [Double], in windowID: UUID) {
        guard let state = window(id: windowID), state.splitFractions != values else { return }
        state.setSplitFractions(values)
        scheduleSave()
    }

    func selectRelative(_ offset: Int, in windowID: UUID? = nil) {
        let state = windowID.flatMap(window(id:)) ?? activeWindow
        guard let state, !state.tabIDs.isEmpty, let id = state.focusedTabID,
              let index = state.tabIDs.firstIndex(of: id) else { return }
        selectTab(id: state.tabIDs[(index + offset + state.tabIDs.count) % state.tabIDs.count], in: state.id)
    }

    func selectTab(number: Int, in windowID: UUID? = nil) {
        let state = windowID.flatMap(window(id:)) ?? activeWindow
        guard let state, !state.tabIDs.isEmpty else { return }
        let index = number == 9 ? state.tabIDs.count - 1 : number - 1
        guard state.tabIDs.indices.contains(index) else { return }
        selectTab(id: state.tabIDs[index], in: state.id)
    }

    func duplicateTab(id: UUID, in windowID: UUID? = nil) {
        guard let tab = tab(id: id) else { return }
        createTab(opening: tab.url, in: windowID ?? ownerWindow(of: id)?.id, isPrivate: tab.isPrivate)
    }

    func reopenLastClosedTab(in windowID: UUID? = nil) {
        guard let record = closedTabs.popLast() else { return }
        let tab = createTab(opening: record.url, in: windowID)
        tab.isPinned = record.isPinned
    }

    func closeOtherTabs(keeping id: UUID) {
        guard let owner = ownerWindow(of: id) else { return }
        for tabID in owner.tabIDs.filter({ $0 != id }) { closeTab(id: tabID) }
    }

    func closeTabsToRight(of id: UUID) {
        guard let owner = ownerWindow(of: id), let index = owner.tabIDs.firstIndex(of: id),
              index + 1 < owner.tabIDs.count else { return }
        for tabID in owner.tabIDs[(index + 1)...].reversed() { closeTab(id: tabID) }
    }

    func moveTab(from source: IndexSet, to destination: Int, in windowID: UUID? = nil) {
        guard let state = windowID.flatMap(window(id:)) ?? activeWindow else { return }
        state.tabIDs.move(fromOffsets: source, toOffset: destination)
        saveSession()
    }

    func moveTab(id: UUID, by offset: Int, in windowID: UUID? = nil) {
        guard let state = windowID.flatMap(window(id:)) ?? ownerWindow(of: id),
              let source = state.tabIDs.firstIndex(of: id) else { return }
        let destination = min(max(source + offset, 0), state.tabIDs.count - 1)
        guard source != destination else { return }
        state.tabIDs.remove(at: source)
        state.tabIDs.insert(id, at: destination)
        saveSession()
    }

    func moveTab(_ tabID: UUID, toWindow destinationID: UUID, activate: Bool = true) {
        guard tab(id: tabID) != nil, let destination = window(id: destinationID) else { return }
        let sources = windows.filter { $0.id != destinationID && $0.tabIDs.contains(tabID) }
        for state in sources { state.removeTab(tabID) }
        destination.insertTab(tabID, activate: activate)
        if let workspaceID = destination.workspaceID {
            workspaceManager?.moveTab(tabID, to: workspaceID)
        }
        if activate { activeWindowID = destinationID }
        if draggedTabID == tabID {
            dragSourceWindowID = destinationID
            dragSourceIndex = destination.tabIDs.firstIndex(of: tabID)
        }
        updateLifecycleStates()
        saveSession()
        requestClosingEmptyWindows(sources)
    }

    func beginDragging(tabID: UUID, from windowID: UUID) {
        guard window(id: windowID)?.tabIDs.contains(tabID) == true else { return }
        draggedTabID = tabID
        dragSourceWindowID = windowID
        dragSourceIndex = window(id: windowID)?.tabIDs.firstIndex(of: tabID)
        dragTargetWindowID = nil
    }

    func setDragTarget(windowID: UUID?, targeted: Bool) {
        if targeted { dragTargetWindowID = windowID }
        else if dragTargetWindowID == windowID { dragTargetWindowID = nil }
    }

    func previewDraggedTab(in windowID: UUID, relativeTo targetTabID: UUID, placeAfter: Bool) {
        guard let tabID = draggedTabID,
              dragSourceWindowID == windowID,
              tabID != targetTabID,
              let destination = window(id: windowID) else { return }
        reorder(tabID, in: destination, relativeTo: targetTabID, placeAfter: placeAfter)
    }

    func completeDrop(
        in windowID: UUID,
        relativeTo targetTabID: UUID? = nil,
        placeAfter: Bool = true
    ) -> Bool {
        guard let tabID = draggedTabID, let destination = window(id: windowID) else { return false }

        if dragSourceWindowID == windowID {
            if let targetTabID, targetTabID != tabID {
                reorder(tabID, in: destination, relativeTo: targetTabID, placeAfter: placeAfter)
            } else if targetTabID == nil {
                destination.tabIDs.removeAll { $0 == tabID }
                destination.tabIDs.append(tabID)
            }
            destination.select(tabID)
            activeWindowID = windowID
        } else {
            let sources = windows.filter { $0.id != windowID && $0.tabIDs.contains(tabID) }
            for state in sources {
                state.removeTab(tabID)
            }
            destination.tabIDs.removeAll { $0 == tabID }
            let insertion = insertionIndex(
                in: destination,
                relativeTo: targetTabID,
                placeAfter: placeAfter
            )
            destination.tabIDs.insert(tabID, at: insertion)
            destination.select(tabID)
            if let workspaceID = destination.workspaceID {
                workspaceManager?.moveTab(tabID, to: workspaceID)
            }
            activeWindowID = windowID
            requestClosingEmptyWindows(sources)
        }

        updateLifecycleStates()
        saveSession()
        clearDragState()
        return true
    }

    func cancelDragging() {
        if let tabID = draggedTabID,
           let sourceWindowID = dragSourceWindowID,
           let originalIndex = dragSourceIndex,
           let source = window(id: sourceWindowID),
           source.tabIDs.contains(tabID) {
            source.tabIDs.removeAll { $0 == tabID }
            source.tabIDs.insert(tabID, at: min(originalIndex, source.tabIDs.count))
        }
        clearDragState()
    }

    func clearDragState() {
        draggedTabID = nil
        dragSourceWindowID = nil
        dragTargetWindowID = nil
        dragSourceIndex = nil
    }

    private func reorder(
        _ tabID: UUID,
        in destination: BrowserWindowState,
        relativeTo targetTabID: UUID,
        placeAfter: Bool
    ) {
        guard destination.tabIDs.contains(tabID), destination.tabIDs.contains(targetTabID) else { return }
        destination.tabIDs.removeAll { $0 == tabID }
        guard let targetIndex = destination.tabIDs.firstIndex(of: targetTabID) else { return }
        let insertion = min(targetIndex + (placeAfter ? 1 : 0), destination.tabIDs.count)
        destination.tabIDs.insert(tabID, at: insertion)
    }

    private func insertionIndex(
        in destination: BrowserWindowState,
        relativeTo targetTabID: UUID?,
        placeAfter: Bool
    ) -> Int {
        guard let targetTabID,
              let targetIndex = destination.tabIDs.firstIndex(of: targetTabID) else {
            return destination.tabIDs.count
        }
        return min(targetIndex + (placeAfter ? 1 : 0), destination.tabIDs.count)
    }

    private func requestClosingEmptyWindows(_ candidates: [BrowserWindowState]) {
        for state in candidates where state.tabIDs.isEmpty {
            let windowID = state.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(320))
                guard let self,
                      self.window(id: windowID)?.tabIDs.isEmpty == true else { return }
                NotificationCenter.default.post(
                    name: .leafBrowserWindowShouldClose,
                    object: windowID.uuidString
                )
            }
        }
    }

    func togglePin(id: UUID) {
        guard let targetTab = tab(id: id) else { return }
        targetTab.isPinned.toggle()
        if let state = ownerWindow(of: id) {
            state.tabIDs.sort {
                guard let lhs = tab(id: $0), let rhs = tab(id: $1) else { return false }
                return lhs.isPinned && !rhs.isPinned
            }
            if let workspaceID = state.workspaceID {
                if targetTab.isPinned { workspaceManager?.pinTab(id, in: workspaceID) }
                else { workspaceManager?.unpinTab(id, in: workspaceID) }
            }
        }
        saveSession()
    }

    func handlePopup(configuration: WKWebViewConfiguration, sourceTabID: UUID,
                     isPrivate: Bool = false) -> WKWebView? {
        guard let sourceWindow = ownerWindow(of: sourceTabID) else { return nil }

        // Keep WebKit's popup in the same browser window and workspace as its
        // opener, even when another LeafOrLeave window is currently active.
        let tab = createTab(
            activate: false,
            configuration: configuration,
            in: sourceWindow.id,
            isPrivate: isPrivate
        )
        if let workspaceID = sourceWindow.workspaceID {
            workspaceManager?.moveTab(tab.id, to: workspaceID)
        }

        let popupTabID = tab.id
        let sourceWindowID = sourceWindow.id
        DispatchQueue.main.async { [weak self] in
            // Activating synchronously removes the opener WKWebView while
            // WebKit is still inside createWebViewWith. Waiting one run-loop
            // turn lets WebKit finish wiring and loading the returned view.
            self?.selectTab(id: popupTabID, in: sourceWindowID)
        }

        // Do not call load(_:) here. WebKit owns navigationAction.request and
        // automatically loads it into the WKWebView returned by this callback.
        return tab.webView
    }

    func navigateSelected(to input: String) -> Bool {
        navigate(tabID: selectedTabID, to: input)
    }

    func navigate(tabID: UUID?, to input: String) -> Bool {
        let preferences = settings?.value
        guard let url = resolver.resolve(input,
                                         engine: preferences?.searchEngine ?? .google,
                                         customTemplate: preferences?.customSearchTemplate ?? ""),
              let tab = tab(id: tabID) else { return false }
        tab.navigationError = nil
        tab.load(url)
        return true
    }

    @discardableResult
    func createTab(navigatingTo input: String, in windowID: UUID? = nil) -> Bool {
        let preferences = settings?.value
        guard let url = resolver.resolve(input,
                                         engine: preferences?.searchEngine ?? .google,
                                         customTemplate: preferences?.customSearchTemplate ?? "") else { return false }
        createTab(opening: url, in: windowID)
        return true
    }

    func openLocalFile() {
        let panel = NSOpenPanel()
        panel.title = "Open File"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.html, .pdf, .plainText, .image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let tab = selectedTab?.url == nil ? selectedTab : createTab()
        tab?.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func applyDeveloperSettings() {
        guard let preferences = settings?.value else { return }
        let captureEnabled = preferences.developerMode && preferences.captureConsoleLogs
        for tab in tabs {
            tab.webView.isInspectable = preferences.developerMode && preferences.webInspector
            tab.webView.evaluateJavaScript(
                "window.__leafDeveloperConsoleCaptureEnabled = \(captureEnabled ? "true" : "false");"
            )
        }
    }

    func tabDidChange(_ tab: BrowserTab) {
        guard tab.url != nil else { return }
        scheduleSave()
    }

    func tabDidFinishNavigation(_ tab: BrowserTab) {
        if !tab.isPrivate {
            libraryManager?.recordVisit(title: tab.title, url: tab.url)
        }
        scheduleSave()
    }

    func tabDidCommitSameDocumentNavigation(_ tab: BrowserTab) {
        if !tab.isPrivate {
            libraryManager?.recordVisit(title: tab.title, url: tab.url)
        }
        scheduleSave()
    }

    func saveSession() {
        let persistentTabs = tabs.filter { !$0.isPrivate }
        let persistentIDs = Set(persistentTabs.map(\.id))
        let selectedIndex = persistentTabs.firstIndex { $0.id == selectedTabID } ?? 0
        let records = persistentTabs.map {
            TabSessionRecord(id: $0.id, url: $0.url, title: $0.title,
                             isPinned: $0.isPinned, lastActiveAt: $0.lastActiveAt)
        }
        let persistentWindows = windows
            .map { $0.sessionRecord(including: persistentIDs) }
            .filter { !$0.tabIDs.isEmpty }
        let persistentActiveWindowID = activeWindowID.flatMap { activeID in
            persistentWindows.contains { $0.id == activeID } ? activeID : persistentWindows.first?.id
        }
        sessionStore.save(BrowserSession(
            tabs: records,
            selectedIndex: selectedIndex,
            windows: persistentWindows,
            activeWindowID: persistentActiveWindowID
        ))
    }

    private func createFallbackWindow() -> BrowserWindowState {
        let state = BrowserWindowState()
        windows.append(state)
        activeWindowID = state.id
        return state
    }

    private func makeRestoredTab(_ record: TabSessionRecord) -> BrowserTab {
        let tab = BrowserTab(id: record.id, webView: webViewFactory.makeWebView(),
                             title: record.title, url: record.url)
        tab.isPinned = record.isPinned
        tab.lastActiveAt = record.lastActiveAt
        tab.manager = self
        if let url = record.url { tab.load(url) }
        return tab
    }

    private func restoreSession() {
        guard let session = sessionStore.load(), !session.tabs.isEmpty else {
            let state = BrowserWindowState()
            windows = [state]
            activeWindowID = state.id
            createTab(in: state.id)
            return
        }

        tabs = session.tabs.map(makeRestoredTab)
        let validIDs = Set(tabs.map(\.id))
        windows = session.windows.map { BrowserWindowState(record: $0, validTabIDs: validIDs) }
            .filter { !$0.tabIDs.isEmpty }

        if windows.isEmpty {
            let selected = tabs[min(max(session.selectedIndex, 0), tabs.count - 1)].id
            windows = [BrowserWindowState(tabIDs: tabs.map(\.id), visibleTabIDs: [selected], focusedTabID: selected)]
        }

        var claimed = Set(windows.flatMap(\.tabIDs))
        if let first = windows.first {
            for tabID in tabs.map(\.id) where claimed.insert(tabID).inserted {
                first.insertTab(tabID, activate: false)
            }
        }
        activeWindowID = session.activeWindowID.flatMap { id in windows.contains { $0.id == id } ? id : nil }
            ?? windows.first?.id
        updateLifecycleStates()
    }

    private func scheduleSave() {
        saveRevision &+= 1
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let revision = saveRevision
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                if revision == saveRevision {
                    saveTask = nil
                    saveSession()
                    return
                }
            }
        }
    }

    private func updateLifecycleStates() {
        let visible = visibleTabIDs
        for tab in tabs {
            if visible.contains(tab.id) {
                tab.restoreIfNeeded()
                tab.lifecycleState = .active
            } else if tab.lifecycleState == .active {
                tab.lifecycleState = .background
            }
        }
    }
}
