//
//  LeafOrLeaveTests.swift
//  LeafOrLeaveTests
//
//  Created by Bapakardhie Pacarnya Yaya on 11/07/26.
//

import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers
import WebKit
@testable import LeafOrLeave

@MainActor
struct LeafOrLeaveTests {
    private let resolver = URLResolver()

    @Test func resolvesCompleteURL() {
        #expect(resolver.resolve("https://developer.apple.com")?.absoluteString == "https://developer.apple.com")
    }

    @Test func resolvesDomainWithoutScheme() {
        #expect(resolver.resolve("github.com")?.absoluteString == "https://github.com")
    }

    @Test func resolvesLocalNetworkAddressesOverHTTP() {
        #expect(resolver.resolve("192.168.1.1")?.absoluteString == "http://192.168.1.1")
        #expect(resolver.resolve("192.168.1.1:8080/admin")?.absoluteString == "http://192.168.1.1:8080/admin")
        #expect(resolver.resolve("router.local")?.absoluteString == "http://router.local")
        #expect(resolver.resolve("localhost:3000")?.absoluteString == "http://localhost:3000")
        #expect(resolver.resolve("8.8.8.8")?.absoluteString == "https://8.8.8.8")
        #expect(resolver.resolve("https://192.168.1.1")?.absoluteString == "https://192.168.1.1")
        #expect(resolver.localHTTPFallback(for: URL(string: "https://192.168.1.1/admin")!)?.absoluteString == "http://192.168.1.1/admin")
        #expect(resolver.localHTTPFallback(for: URL(string: "https://github.com")!) == nil)
    }

    @Test func resolvesKeywordsAsGoogleSearch() {
        let url = resolver.resolve("Swift WKWebView")
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.host == "www.google.com")
        #expect(components?.queryItems?.first?.value == "Swift WKWebView")
    }

    @Test func navigationErrorsAreClassifiedForRecoveryUI() {
        let offline = BrowserNavigationError.navigationFailure(
            from: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            failingURL: URL(string: "https://example.com")
        )
        #expect(offline.failureKind == .offline)
        #expect(offline.address == "https://example.com")
        #expect(offline.systemImage == "wifi.slash")

        let dns = BrowserNavigationError.navigationFailure(
            from: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost),
            failingURL: URL(string: "https://missing.example")
        )
        #expect(dns.failureKind == .dns)
        #expect(dns.title == "Website not found")
    }

    @Test func resolvesConfiguredSearchEngines() {
        #expect(resolver.resolve("privacy browser", engine: .duckDuckGo)?.host == "duckduckgo.com")
        #expect(resolver.resolve("swift webkit", engine: .bing)?.host == "www.bing.com")
        let custom = resolver.resolve("hello world", engine: .custom,
                                      customTemplate: "https://search.example/?term={query}")
        #expect(custom?.host == "search.example")
        #expect(URLComponents(url: custom!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "hello world")
    }

    @Test func webViewAdvertisesSafariCompatibility() async throws {
        let webView = WebViewFactory(configuration: .default).makeWebView()
        let result = try await webView.evaluateJavaScript("navigator.userAgent")
        let userAgent = try #require(result as? String)

        #expect(userAgent.contains("AppleWebKit/"))
        #expect(userAgent.contains(" Version/"))
        #expect(userAgent.contains(" Safari/"))
    }

    @Test func embeddingWebViewDoesNotInstallClickBlockingRecognizer() {
        let webView = WebViewFactory(configuration: .default).makeWebView()
        let existingRecognizers = Set(webView.gestureRecognizers.map(ObjectIdentifier.init))
        let host = NSHostingView(rootView: WebViewContainer(webView: webView))
        host.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        host.layoutSubtreeIfNeeded()

        let newlyInstalledRecognizers = webView.gestureRecognizers.filter {
            !existingRecognizers.contains(ObjectIdentifier($0))
        }
        #expect(newlyInstalledRecognizers.allSatisfy { !($0 is NSClickGestureRecognizer) })
    }

    @Test func toolbarButtonHitTargetIncludesItsCorners() {
        let host = NSHostingView(rootView: BrowserToolbarButton(
            systemName: "star",
            helpText: "Test"
        ) {})
        host.frame = CGRect(
            x: 0,
            y: 0,
            width: BrowserChromeMetrics.controlSize,
            height: BrowserChromeMetrics.controlSize
        )
        host.layoutSubtreeIfNeeded()

        #expect(host.hitTest(NSPoint(x: 2, y: 2)) != nil)
        #expect(host.hitTest(NSPoint(
            x: BrowserChromeMetrics.controlSize - 2,
            y: BrowserChromeMetrics.controlSize - 2
        )) != nil)
    }

    @Test func workspaceDefaultsAndMutation() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let manager = WorkspaceManager(defaults: suite)
        #expect(manager.workspaces.map(\.name) == ["Study", "Coding", "Media"])
        manager.createWorkspace(name: "Research")
        let custom = manager.workspaces.last!
        manager.renameWorkspace(id: custom.id, name: "Thesis")
        #expect(manager.workspaces.last?.name == "Thesis")
        manager.deleteWorkspace(id: custom.id)
        #expect(manager.workspaces.count == 3)
    }

    @Test func workspaceMovesAndPinsTab() {
        let manager = WorkspaceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let tab = UUID(), target = manager.workspaces[1].id
        manager.moveTab(tab, to: target); manager.pinTab(tab, in: target)
        #expect(manager.workspaces[1].tabIDs.contains(tab))
        #expect(manager.workspaces[1].pinnedTabIDs.contains(tab))
        manager.unpinTab(tab, in: target)
        #expect(!manager.workspaces[1].pinnedTabIDs.contains(tab))
    }

    @Test func workspaceReconciliationKeepsTabOwnershipSeparate() {
        let manager = WorkspaceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let studyID = manager.workspaces[0].id
        let codingID = manager.workspaces[1].id
        let studyTab = UUID()
        let staleTab = UUID()
        let codingTab = UUID()

        manager.moveTab(studyTab, to: studyID)
        manager.moveTab(staleTab, to: studyID)
        manager.selectWorkspace(id: codingID)
        manager.reconcileTabs([studyTab, codingTab], assigningUnownedTo: codingID)

        #expect(manager.workspaces[0].tabIDs == [studyTab])
        #expect(manager.workspaces[1].tabIDs == [codingTab])
        #expect(manager.workspaces[1].selectedTabID == codingTab)

        manager.rememberSelection(studyTab)
        #expect(manager.workspaces[1].selectedTabID == codingTab)
    }

    @Test func settingsDefaultsAndSearchValidation() {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(settings.value.appearance == .graphiteDark)
        #expect(settings.value.suspensionAggressiveness == 0.6)
        #expect(settings.value.keepPinnedTabsAlive)
        #expect(settings.value.autoFillPasswords)
        #expect(settings.value.offerToSavePasswords)
        #expect(settings.value.tabPlacement == .top)
        #expect(settings.value.toolbarStyle == .unified)
        #expect(settings.value.toolbarIconScale == .regular)
        #expect(settings.value.newTabBackgroundStyle == .ambient)
        #expect(settings.value.useWorkspaceAccent)
        settings.value.customSearchTemplate = "https://search.example/?q={query}"
        #expect(settings.validCustomSearchTemplate())
        settings.value.customSearchTemplate = "https://search.example/"
        #expect(!settings.validCustomSearchTemplate())
    }

    @Test func settingsMigrationSuppliesSecureAndPerformanceDefaults() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        suite.set(Data("{}".utf8), forKey: "settings.typed.v1")
        let settings = SettingsStore(defaults: suite)

        #expect(settings.value.smartSuspension)
        #expect(settings.value.idleTimeout == 900)
        #expect(settings.value.suspensionAggressiveness == 0.6)
        #expect(settings.value.keepExamTabsAlive)
        #expect(settings.value.passwordAutoLockMinutes == 5)
        #expect(settings.value.autoFillPasswords)
        #expect(settings.value.tabPlacement == .top)
        #expect(settings.value.toolbarStyle == .unified)
        #expect(!settings.value.useCustomAccent)
        #expect(settings.shortcut(for: .newTab).display == "⌘T")
    }

    @Test func customKeyboardShortcutsPersistAndDetectConflicts() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        var settings: SettingsStore? = SettingsStore(defaults: suite)
        let custom = BrowserShortcut(key: "k", modifiers: [.command, .option])
        settings?.setShortcut(custom, for: .newTab)
        settings?.setShortcut(custom, for: .reload)
        #expect(settings?.shortcut(for: .reload) == custom)
        #expect(settings?.shortcut(for: .newTab) == BrowserShortcutDefaults.values[.reload])
        settings = nil

        let restored = SettingsStore(defaults: suite)
        #expect(restored.shortcut(for: .reload) == custom)
        #expect(restored.shortcut(for: .reload).display == "⌥⌘K")
        restored.resetKeyboardShortcuts()
        #expect(restored.shortcut(for: .newTab) == BrowserShortcutDefaults.values[.newTab])
    }

    @Test func appearanceCustomizationPersists() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        var settings: SettingsStore? = SettingsStore(defaults: suite)
        settings?.value.tabPlacement = .left
        settings?.value.toolbarStyle = .floating
        settings?.value.toolbarIconScale = .large
        settings?.value.newTabBackgroundStyle = .solid
        settings?.value.useCustomAccent = true
        settings?.value.useWorkspaceAccent = false
        settings?.value.customAccent = UserAccentColor(
            red: 0.1,
            green: 0.2,
            blue: 0.3,
            opacity: 1
        )
        settings = nil

        let restored = SettingsStore(defaults: suite)
        #expect(restored.value.tabPlacement == .left)
        #expect(restored.value.toolbarStyle == .floating)
        #expect(restored.value.toolbarIconScale == .large)
        #expect(restored.value.newTabBackgroundStyle == .solid)
        #expect(restored.value.useCustomAccent)
        #expect(!restored.value.useWorkspaceAccent)
        #expect(restored.value.customAccent == UserAccentColor(
            red: 0.1,
            green: 0.2,
            blue: 0.3,
            opacity: 1
        ))
    }

    @Test func historyAutocompletePrefersFrequentlyVisitedPrefixMatches() {
        let manager = LibraryManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let calendar = URL(string: "https://calendar.example/")!
        let chat = URL(string: "https://chatgpt.com/")!
        let start = Date(timeIntervalSince1970: 1_000)

        manager.recordVisit(title: "Calendar", url: calendar, at: start)
        manager.recordVisit(title: "Calendar", url: calendar, at: start.addingTimeInterval(31))
        manager.recordVisit(title: "Calendar", url: calendar, at: start.addingTimeInterval(62))
        manager.recordVisit(title: "ChatGPT", url: chat, at: start.addingTimeInterval(93))

        #expect(manager.autocompleteSuggestion(for: "c") == "calendar.example")
        #expect(manager.autocompleteSuggestion(for: "ch") == "chatgpt.com")
        #expect(manager.autocompleteSuggestion(for: "search words") == nil)
    }

    @Test func legacyHistoryWithoutVisitCountStillLoads() throws {
        struct LegacyEntry: Encodable {
            let id: UUID
            let title: String
            let url: URL
            let date: Date
        }

        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let original = LegacyEntry(
            id: UUID(),
            title: "Example",
            url: URL(string: "https://example.com")!,
            date: .now
        )
        defaults.set(try JSONEncoder().encode([original]), forKey: "library.history.v1")

        let manager = LibraryManager(defaults: defaults)
        #expect(manager.history.first?.visitCount == 1)
        #expect(manager.autocompleteSuggestion(for: "e") == "example.com")
    }

    @Test func webKitUsesPersistentWebsiteSessions() {
        let configuration = BrowserConfiguration.default.makeWebViewConfiguration()
        #expect(configuration.websiteDataStore.isPersistent)
    }

    @Test func privateTabsUseEphemeralStorageAndNeverRecordHistory() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let library = LibraryManager(defaults: defaults)
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        manager.libraryManager = library
        let privateTab = manager.createPrivateTab(opening: URL(string: "https://private.example"))

        #expect(privateTab.isPrivate)
        #expect(!privateTab.webView.configuration.websiteDataStore.isPersistent)
        manager.tabDidFinishNavigation(privateTab)
        #expect(library.history.isEmpty)
    }

    @Test func privateTabsAreExcludedFromRestoredSessions() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SessionStore(defaults: defaults)
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: false
        )
        let regularTabID = try #require(manager.selectedTabID)
        manager.createPrivateTab(opening: URL(string: "https://private.example"))
        manager.closeTab(id: regularTabID)
        manager.saveSession()

        #expect(store.load()?.tabs.isEmpty == true)
        #expect(store.load()?.windows.isEmpty == true)
    }

    @Test func historyAPINavigationUpdatesBackAndForwardState() async throws {
        let webView = WebViewFactory(configuration: .default).makeWebView()
        let tab = BrowserTab(webView: webView)
        defer { tab.tearDown() }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "leaf-navigation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appending(path: "first.html")
        let second = directory.appending(path: "second.html")
        try Data("<html><head><title>First</title></head><body>First</body></html>".utf8).write(to: first)
        try Data("<html><head><title>Second</title></head><body>Second</body></html>".utf8).write(to: second)
        webView.loadFileURL(first, allowingReadAccessTo: directory)

        for _ in 0..<100 where tab.title != "First" {
            try await Task.sleep(for: .milliseconds(20))
        }
        webView.loadFileURL(second, allowingReadAccessTo: directory)
        for _ in 0..<100 where tab.title != "Second" || !tab.canGoBack {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(tab.title == "Second")
        #expect(tab.canGoBack)

        #expect(tab.navigateBack())
        for _ in 0..<100 where tab.title != "First" {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(tab.title == "First")
        #expect(tab.canGoForward)

        #expect(tab.navigateForward())
        for _ in 0..<100 where tab.title != "Second" {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(tab.title == "Second")
        #expect(NavigationStateScriptProvider.source.contains("sameDocumentCanGoBack"))
        #expect(NavigationStateScriptProvider.source.contains("history[method]"))
    }

    @Test func startupCanSkipTheSavedTabSession() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let store = SessionStore(defaults: suite)
        store.save(BrowserSession(
            tabs: [
                TabSessionRecord(
                    url: URL(string: "https://example.com"),
                    title: "Saved",
                    isPinned: false,
                    lastActiveAt: .now
                )
            ],
            selectedIndex: 0
        ))

        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: false
        )
        #expect(manager.tabs.count == 1)
        #expect(manager.selectedTab?.url == nil)
        #expect(manager.selectedTab?.title == "New Tab")
    }

    @Test func splitModeShowsAtMostThreeDistinctTabsAndTracksFocus() throws {
        let first = UUID(), second = UUID(), third = UUID(), fourth = UUID()
        let window = BrowserWindowState(
            tabIDs: [first, second, third, fourth],
            visibleTabIDs: [first],
            focusedTabID: first
        )

        #expect(window.addSplit(second))
        #expect(window.addSplit(third))
        #expect(!window.addSplit(fourth))
        #expect(window.visibleTabIDs == [first, second, third])
        #expect(window.focusedTabID == third)

        window.removeSplit(second)
        #expect(window.visibleTabIDs == [first, third])
        window.exitSplit(keeping: first)
        #expect(window.visibleTabIDs == [first])
        #expect(window.focusedTabID == first)
    }

    @Test func splitResizeKeepsPanelsValidAndOnlyMovesAdjacentPanels() {
        let starting = [0.25, 0.35, 0.40]
        let resized = BrowserWindowState.resizedSplitFractions(
            from: starting,
            after: 0,
            translation: 500,
            availableWidth: 1_000,
            minimumPanelWidth: 180
        )

        #expect(abs(resized.reduce(0, +) - 1) < 0.000_001)
        #expect(resized[0] >= 0.18)
        #expect(resized[1] >= 0.18)
        #expect(abs(resized[2] - starting[2]) < 0.000_001)

        let resizedBack = BrowserWindowState.resizedSplitFractions(
            from: resized,
            after: 1,
            translation: -1_000,
            availableWidth: 1_000,
            minimumPanelWidth: 180
        )
        #expect(resizedBack[1] >= 0.18)
        #expect(resizedBack[2] >= 0.18)
        #expect(abs(resizedBack.reduce(0, +) - 1) < 0.000_001)
    }

    @Test func movingTabBetweenWindowsPreservesTheWebViewInstance() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        let source = try #require(manager.activeWindow)
        let movedTab = manager.createTab(in: source.id)
        let originalWebView = movedTab.webView

        let destination = manager.createWindow(moving: movedTab.id)

        #expect(!source.tabIDs.contains(movedTab.id))
        #expect(destination.tabIDs.contains(movedTab.id))
        #expect(manager.tab(id: movedTab.id)?.webView === originalWebView)
        #expect(manager.ownerWindow(of: movedTab.id)?.id == destination.id)
    }

    @Test func dragDetachDecisionUsesPointerAndDestinationWindow() {
        let source = UUID(), destination = UUID()
        let frame = CGRect(x: 100, y: 100, width: 900, height: 650)

        #expect(!TabDragDetachDecision.shouldDetach(
            hasDraggedTab: true, dragTargetWindowID: source, sourceWindowID: source,
            pointer: CGPoint(x: 400, y: 400), sourceFrame: frame
        ))
        #expect(TabDragDetachDecision.shouldDetach(
            hasDraggedTab: true, dragTargetWindowID: source, sourceWindowID: source,
            pointer: CGPoint(x: 1_150, y: 400), sourceFrame: frame
        ))
        #expect(!TabDragDetachDecision.shouldDetach(
            hasDraggedTab: true, dragTargetWindowID: destination, sourceWindowID: source,
            pointer: CGPoint(x: 1_150, y: 400), sourceFrame: frame
        ))
    }

    @Test func tabDragTypeCannotBeExportedAsDesktopFileData() {
        #expect(!UTType.leafBrowserTab.conforms(to: .data))
        #expect(!UTType.leafBrowserTab.conforms(to: .fileURL))
    }

    @Test func tabDragPreviewReordersSmoothlyAndCancelRestoresOriginalOrder() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        let window = try #require(manager.activeWindow)
        let second = manager.createTab(activate: false, in: window.id)
        let third = manager.createTab(activate: false, in: window.id)
        let originalOrder = window.tabIDs

        manager.beginDragging(tabID: third.id, from: window.id)
        manager.previewDraggedTab(
            in: window.id,
            relativeTo: originalOrder[0],
            placeAfter: false
        )
        #expect(window.tabIDs.first == third.id)

        manager.cancelDragging()
        #expect(window.tabIDs == originalOrder)
        #expect(window.tabIDs.contains(second.id))
    }

    @Test func tabDropCanInsertIntoAnotherWindowAtTheTargetPosition() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        let source = try #require(manager.activeWindow)
        let moved = manager.createTab(activate: false, in: source.id)
        let originalWebView = moved.webView
        let destination = manager.createWindow()
        let target = try #require(destination.tabIDs.first)

        manager.beginDragging(tabID: moved.id, from: source.id)
        #expect(manager.completeDrop(
            in: destination.id,
            relativeTo: target,
            placeAfter: false
        ))

        #expect(destination.tabIDs.first == moved.id)
        #expect(!source.tabIDs.contains(moved.id))
        #expect(manager.ownerWindow(of: moved.id)?.id == destination.id)
        #expect(manager.tab(id: moved.id)?.webView === originalWebView)
        #expect(manager.draggedTabID == nil)
    }

    @Test func liveDetachedTabCanReturnAndLeavesDetachedWindowEmpty() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        let originalWindow = try #require(manager.activeWindow)
        let tabID = try #require(originalWindow.tabIDs.first)

        manager.beginDragging(tabID: tabID, from: originalWindow.id)
        let detachedWindow = manager.createWindow(moving: tabID)

        #expect(manager.dragSourceWindowID == detachedWindow.id)
        #expect(detachedWindow.tabIDs == [tabID])
        #expect(originalWindow.tabIDs.isEmpty)

        #expect(manager.completeDrop(in: originalWindow.id))
        #expect(originalWindow.tabIDs == [tabID])
        #expect(detachedWindow.tabIDs.isEmpty)
        #expect(manager.ownerWindow(of: tabID)?.id == originalWindow.id)
    }

    @Test func repeatedCrossWindowDragsNeverCreateReplacementTabs() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        let original = try #require(manager.activeWindow)
        let movingTab = manager.createTab(activate: false, in: original.id)
        let other = manager.createWindow()
        let originalTabIDs = Set(manager.tabs.map(\.id))

        for _ in 0..<6 {
            manager.beginDragging(tabID: movingTab.id, from: original.id)
            #expect(manager.completeDrop(in: other.id))
            #expect(manager.ownerWindow(of: movingTab.id)?.id == other.id)

            manager.beginDragging(tabID: movingTab.id, from: other.id)
            #expect(manager.completeDrop(in: original.id))
            #expect(manager.ownerWindow(of: movingTab.id)?.id == original.id)
        }

        #expect(Set(manager.tabs.map(\.id)) == originalTabIDs)
        #expect(manager.tabs.count == originalTabIDs.count)
        #expect(manager.windows.flatMap(\.tabIDs).filter { $0 == movingTab.id }.count == 1)
    }

    @Test func sessionRestoresWindowOwnershipAndSplitLayout() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SessionStore(defaults: defaults)
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: false
        )
        let firstWindow = try #require(manager.activeWindow)
        let secondTab = manager.createTab(activate: false, in: firstWindow.id)
        #expect(manager.addToSplit(tabID: secondTab.id, in: firstWindow.id))
        firstWindow.setSplitFractions([0.62, 0.38])
        firstWindow.frame = CGRect(x: 40, y: 60, width: 1100, height: 720)

        let thirdTab = manager.createTab(activate: false, in: firstWindow.id)
        let secondWindow = manager.createWindow(moving: thirdTab.id)
        manager.saveSession()

        let restored = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: true
        )
        let restoredFirst = try #require(restored.window(id: firstWindow.id))
        let restoredSecond = try #require(restored.window(id: secondWindow.id))

        #expect(restored.windows.count == 2)
        #expect(restoredFirst.visibleTabIDs.count == 2)
        #expect(restoredFirst.splitFractions == [0.62, 0.38])
        #expect(restoredFirst.frame == firstWindow.frame)
        #expect(restoredSecond.tabIDs == [thirdTab.id])
        #expect(Set(restored.windows.flatMap(\.tabIDs)) == Set(restored.tabs.map(\.id)))
    }

    @Test func closingEveryWindowPersistsAnEmptySessionAndCanReopenSafely() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SessionStore(defaults: defaults)
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: store,
            restoresPreviousSession: false
        )
        let window = try #require(manager.activeWindow)
        let closedTabID = try #require(manager.selectedTabID)

        manager.closeWindow(id: window.id)

        #expect(manager.windows.isEmpty)
        #expect(manager.tabs.isEmpty)
        #expect(store.load()?.tabs.isEmpty == true)

        let reopenedWindowID = manager.initialWindowID
        #expect(manager.window(id: reopenedWindowID) != nil)
        #expect(manager.tabs.count == 1)
        #expect(manager.selectedTabID != closedTabID)
    }

    @Test func passwordCredentialsNormalizeHostsAndEscapeAutofillPayload() throws {
        let credential = PasswordCredential(
            host: "https://WWW.Example.COM/login",
            username: " captain@example.com ",
            password: "secret"
        )
        #expect(credential.host == "example.com")
        #expect(credential.username == "captain@example.com")

        let script = try #require(
            PasswordScriptProvider.autofillScript(
                username: "captain\"@example.com",
                password: "</script>\"quoted"
            )
        )
        #expect(script.contains("captain\\\"@example.com"))
        #expect(script.contains("<\\/script>"))
    }

    @Test func passwordCaptureSupportsButtonDrivenMultiStepSignIn() async throws {
        let recorder = PasswordMessageRecorder()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(
            recorder,
            name: PasswordScriptProvider.name
        )
        configuration.userContentController.addUserScript(PasswordScriptProvider.script)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <body>
                <input id="identifierId" type="email" autocomplete="username">
                <div id="identifierNext" role="button">Next</div>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://accounts.google.test")
        )

        for _ in 0..<50 {
            let fixtureLoaded = (try? await webView.evaluateJavaScript(
                "document.getElementById('identifierId') !== null"
            )) as? Bool
            if fixtureLoaded == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let fixtureLoaded = try await webView.evaluateJavaScript(
            "document.getElementById('identifierId') !== null"
        ) as? Bool
        #expect(fixtureLoaded == true)

        _ = try await webView.evaluateJavaScript(
            """
            const email = document.getElementById('identifierId');
            email.value = 'captain@gmail.com';
            email.dispatchEvent(new Event('input', { bubbles: true }));
            document.getElementById('identifierNext').click();
            document.body.innerHTML = `
              <input type="hidden" name="identifier" value="selected.account@gmail.com">
              <input id="password" name="login_password" type="text" placeholder="PIC/Password">
              <div id="passwordNext" role="button">Next</div>
            `;
            window.__leafPasswordCaptureEnabled = true;
            document.getElementById('password').value = 'automatic-secret';
            document.getElementById('passwordNext').click();
            """
        )

        var submission: [String: Any]?
        for _ in 0..<50 {
            submission = recorder.messages.last {
                $0["type"] as? String == "submitted"
            }
            if submission != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(submission?["host"] as? String == "accounts.google.test")
        #expect(submission?["username"] as? String == "selected.account@gmail.com")
        #expect(submission?["password"] as? String == "automatic-secret")
        #expect(submission?["passwordKind"] as? String == "current")

        let submittedDocumentID = try #require(submission?["documentID"] as? String)
        _ = try await webView.evaluateJavaScript(
            "document.body.innerHTML = '<main id=\"signedIn\">Signed in</main>';"
        )
        var successfulPageState: [String: Any]?
        for _ in 0..<50 {
            successfulPageState = recorder.messages.last {
                $0["type"] as? String == "pageState" &&
                $0["documentID"] as? String == submittedDocumentID &&
                $0["hasPassword"] as? Bool == false
            }
            if successfulPageState != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(successfulPageState != nil)

        _ = try await webView.evaluateJavaScript(
            """
            document.body.innerHTML = `
              <input id="studentNumber" type="text" name="student_number">
              <input id="picPassword" type="text" placeholder="PIC/Password">
            `;
            """
        )
        let autofillScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "202410370110053",
                password: "saved-umm-password"
            )
        )
        _ = try await webView.evaluateJavaScript(autofillScript)
        let autofilled = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('studentNumber').value,
              password: document.getElementById('picPassword').value
            })
            """
        ) as? [String: String]
        #expect(autofilled?["username"] == "202410370110053")
        #expect(autofilled?["password"] == "saved-umm-password")

        let selectedAccountScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "202410370110248",
                password: "other-account-password",
                replacingExistingValues: true
            )
        )
        _ = try await webView.evaluateJavaScript(selectedAccountScript)
        let selectedAccount = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('studentNumber').value,
              password: document.getElementById('picPassword').value
            })
            """
        ) as? [String: String]
        #expect(selectedAccount?["username"] == "202410370110248")
        #expect(selectedAccount?["password"] == "other-account-password")

        _ = try await webView.evaluateJavaScript(
            """
            document.body.innerHTML = `
              <input id="signupEmail" type="email" autocomplete="username">
              <input id="newPassword" type="password" autocomplete="new-password">
            `;
            """
        )
        let returningUserScript = try #require(
            PasswordScriptProvider.autofillScript(
                username: "returning@example.com",
                password: "must-not-fill-a-new-password"
            )
        )
        _ = try await webView.evaluateJavaScript(returningUserScript)
        let signupAutofill = try await webView.evaluateJavaScript(
            """
            ({
              username: document.getElementById('signupEmail').value,
              password: document.getElementById('newPassword').value
            })
            """
        ) as? [String: String]
        #expect(signupAutofill?["username"] == "returning@example.com")
        #expect(signupAutofill?["password"] == "")
    }

    @Test func passwordSaveOfferWaitsForSuccessfulLoginEvidence() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = SettingsStore(defaults: defaults)
        settings.value.onboardingCompleted = true
        settings.value.offerToSavePasswords = true
        let vault = PasswordVault(
            service: "app.leaforleave.tests.pending-password.\(UUID().uuidString)",
            authenticator: { _ in }
        )
        let manager = TabManager(
            webViewFactory: WebViewFactory(configuration: .default),
            sessionStore: SessionStore(defaults: defaults),
            restoresPreviousSession: false
        )
        manager.settings = settings
        manager.passwordVault = vault
        let tab = try #require(manager.selectedTab)

        tab.webView.loadHTMLString(
            """
            <!doctype html>
            <html>
              <body>
                <form id="login">
                  <input id="email" type="email" autocomplete="username">
                  <input id="password" type="password" autocomplete="current-password">
                  <button id="submit" type="submit">Sign in</button>
                </form>
                <script>
                  document.getElementById('login').addEventListener(
                    'submit',
                    event => event.preventDefault()
                  );
                </script>
              </body>
            </html>
            """,
            baseURL: URL(string: "https://accounts.flow.test/signin")
        )

        for _ in 0..<75 {
            let ready = (try? await tab.webView.evaluateJavaScript(
                "document.getElementById('login') !== null && window.__leafPasswordManagerInstalled"
            )) as? Bool
            if ready == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(100))

        _ = try await tab.webView.evaluateJavaScript(
            """
            const email = document.getElementById('email');
            const password = document.getElementById('password');
            email.value = 'captain@example.com';
            email.dispatchEvent(new Event('input', { bubbles: true }));
            password.value = 'wrong-password';
            document.getElementById('submit').click();
            """
        )
        try await Task.sleep(for: .milliseconds(1_300))
        #expect(tab.passwordSaveOffer == nil)

        _ = try await tab.webView.evaluateJavaScript(
            """
            document.getElementById('password').value = 'accepted-password';
            document.getElementById('submit').click();
            setTimeout(() => {
              document.getElementById('login')?.remove();
              document.body.insertAdjacentHTML('beforeend', '<main id="account">Account</main>');
            }, 50);
            """
        )
        for _ in 0..<100 {
            if tab.passwordSaveOffer != nil { break }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(tab.passwordSaveOffer?.host == "accounts.flow.test")
        #expect(tab.passwordSaveOffer?.username == "captain@example.com")
        tab.dismissPasswordSaveOffer()
    }

    @Test func passwordVaultRoundTripsThroughKeychain() async throws {
        let service = "app.leaforleave.tests.passwords.\(UUID().uuidString)"
        let vault = PasswordVault(
            service: service,
            authenticator: { _ in }
        )

        #expect(await vault.unlock(reason: "Test Keychain access"))
        let saved = try vault.save(
            host: "https://accounts.example.com/login",
            username: "captain@example.com",
            password: "correct horse battery staple"
        )

        vault.lock()
        #expect(await vault.unlock(reason: "Test Keychain reload"))
        #expect(vault.credential(for: "accounts.example.com") == saved)

        let second = try vault.save(
            host: "accounts.example.com",
            username: "first.mate@example.com",
            password: "another secure password"
        )
        #expect(Set(vault.credentials(for: "accounts.example.com").map(\.username)) == [
            "captain@example.com",
            "first.mate@example.com"
        ])

        try vault.delete(saved)
        try vault.delete(second)
        #expect(vault.storedCredentialCount == 0)
        vault.lock()
    }

    @Test func equalizerCompensatesPositiveGain() {
        let model = EqualizerViewModel()
        model.select(EqualizerPreset(name: "Test", gains: [6, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(model.preamp == -6)
    }

    @Test func equalizerProcessorIsInstalledAtDocumentStart() async throws {
        let webView = WebViewFactory(configuration: .default).makeWebView()
        let tab = BrowserTab(webView: webView)
        defer { tab.tearDown() }
        webView.loadHTMLString("<html><body><audio controls></audio></body></html>", baseURL: nil)

        var installed = false
        for _ in 0..<80 {
            if let result = try? await webView.evaluateJavaScript(
                "typeof window.__leafEqualizerController?.apply === 'function'"
            ) as? Bool, result {
                installed = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(installed)
        #expect(EqualizerScriptProvider.source.contains(
            "state.enabled ? Math.pow(10, state.preamp / 20) : 1"
        ))
        #expect(EqualizerScriptProvider.source.contains("document.addEventListener('play'"))
    }

    @Test func sharedFormattingProducesStableBrowserLabels() {
        #expect(LeafFormatting.mediaTime(0) == "0:00")
        #expect(LeafFormatting.mediaTime(65) == "1:05")
        #expect(LeafFormatting.mediaTime(3_661) == "1:01:01")
        #expect(LeafFormatting.percentage(-1) == "0%")
        #expect(LeafFormatting.percentage(0.426) == "43%")
        #expect(LeafFormatting.percentage(2) == "100%")
        #expect(
            LeafFormatting.displayHost(URL(string: "https://www.example.com/path"))
                == "example.com"
        )
    }

    @Test func diagnosticLogBufferIsBoundedAndKeepsNewestEvents() {
        let store = LeafLogStore(capacity: 2)
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .info,
                category: .app,
                message: "first"
            )
        )
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .notice,
                category: .network,
                message: "second"
            )
        )
        store.append(
            LeafLogEntry(
                date: .distantPast,
                level: .warning,
                category: .browser,
                message: "third"
            )
        )

        #expect(store.entries().map(\.message) == ["second", "third"])
        #expect(store.entries(limit: 1).map(\.message) == ["third"])

        store.setCollectionEnabled(false)
        store.append(
            LeafLogEntry(
                date: .distantFuture,
                level: .error,
                category: .app,
                message: "disabled"
            )
        )
        #expect(store.entries().isEmpty)
    }
}

@MainActor
private final class PasswordMessageRecorder: NSObject, WKScriptMessageHandler {
    private(set) var messages: [[String: Any]] = []

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        messages.append(body)
    }
}
