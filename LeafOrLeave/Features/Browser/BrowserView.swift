import SwiftUI
import WebKit

struct BrowserView: View {
    let tabManager: TabManager
    let networkMonitor: NetworkMonitor
    let examProtection: ExamProtectionManager
    let suspensionManager: TabSuspensionManager
    let workspaceManager: WorkspaceManager
    let downloadManager: DownloadManager
    let mediaCoordinator: MediaCoordinator
    let settings: SettingsStore
    let libraryManager: LibraryManager
    @State private var addressText = ""
    @State private var showInspector = false
    @State private var validatingNetwork = false
    @State private var showDownloads = false
    @State private var showMedia = false
    @State private var showEqualizer = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showFindBar = false
    @State private var findText = ""
    @State private var findResult = ""
    @State private var showPermissions = false
    @State private var equalizer = EqualizerViewModel()
    @FocusState private var omniboxFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
          if settings.value.showSidebar {
            BrowserSidebarView(workspaces: workspaceManager, downloads: downloadManager, network: networkMonitor,
                               select: selectWorkspace, showBookmarks: { showBookmarks = true },
                               showHistory: { showHistory = true }, showDownloads: { showDownloads = true },
                               collapse: { withAnimation(.easeInOut(duration: 0.18)) { settings.value.showSidebar = false } })
            Divider()
          }
          VStack(spacing: 0) {
            TabBarView(manager: tabManager, visibleTabIDs: Set(workspaceManager.selectedWorkspace?.tabIDs ?? []))
            toolbar
            progress
            ZStack(alignment: .topTrailing) {
              content
              if showFindBar { findBar.padding(.top, 10).padding(.trailing, 14) }
            }
          }
        }
        .background(LeafColors.background)
        .background { Button("") { showFindBar = true }.keyboardShortcut("f", modifiers: .command).hidden() }
        .preferredColorScheme(.dark)
        .onChange(of: tabManager.selectedTabID) { _, _ in syncAddress() }
        .onChange(of: tabManager.selectedTab?.url) { _, _ in syncAddress() }
        .onKeyPress(.tab, phases: .down) { event in
            guard event.modifiers.contains(.control) else { return .ignored }
            tabManager.selectRelative(event.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        }
        .onKeyPress(phases: .down) { event in
            guard event.modifiers == .command, let number = Int(event.characters), (1...9).contains(number) else { return .ignored }
            tabManager.selectTab(number: number)
            return .handled
        }
        .alert("Navigation Error", isPresented: errorPresented) {
            Button("OK", role: .cancel) { tabManager.selectedTab?.navigationError = nil }
        } message: {
            Text(tabManager.selectedTab?.navigationError?.localizedDescription ?? "Unknown error")
        }
        .sheet(isPresented: $showInspector) { BrowserInspectorView(manager: tabManager, suspension: suspensionManager) }
        .sheet(isPresented: $showDownloads) { DownloadsListView(manager: downloadManager) }
        .sheet(isPresented: $showBookmarks) { LibraryListView(manager: libraryManager, kind: .bookmarks, open: openLibraryURL) }
        .sheet(isPresented: $showHistory) { LibraryListView(manager: libraryManager, kind: .history, open: openLibraryURL) }
        .sheet(isPresented: $showPermissions) { PermissionsView() }
        .popover(isPresented: $showMedia) { MiniMediaPanel(coordinator: mediaCoordinator) { tabManager.selectTab(id: $0) } }
        .sheet(isPresented: $showEqualizer) { EqualizerView(model: equalizer) { if let webView = tabManager.selectedTab?.webView { equalizer.apply(to: webView) } } }
        .onChange(of: tabManager.tabs.map(\.id)) { _, ids in workspaceManager.assignUnownedTabs(ids) }
        .onChange(of: tabManager.selectedTabID) { _, id in workspaceManager.rememberSelection(id) }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if !connected, let tab = tabManager.selectedTab, tab.isExamProtected { Task { await examProtection.snapshot(tab) } }
        }
    }

    @ViewBuilder private var content: some View {
        if let tab = tabManager.selectedTab {
            if tab.url == nil && !tab.isLoading {
                NewTabPageView { input in
                    addressText = input
                    submitAddress()
                }
            } else {
                ZStack {
                    WebViewContainer(webView: tab.webView)
                    if tab.isExamProtected, !networkMonitor.isConnected, let since = networkMonitor.offlineSince {
                        RecoveryOverlayView(since: since) { validateConnectivity() }
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: LeafSpacing.small) {
            if !settings.value.showSidebar {
                BrowserToolbarButton(systemName: "sidebar.left", helpText: "Show Sidebar (⌘⇧S)") {
                    withAnimation(.easeInOut(duration: 0.18)) { settings.value.showSidebar = true }
                }
            }
            BrowserToolbarButton(systemName: "chevron.left", helpText: "Back", isEnabled: tabManager.selectedTab?.canGoBack == true) { tabManager.selectedTab?.webView.goBack() }
            BrowserToolbarButton(systemName: "chevron.right", helpText: "Forward", isEnabled: tabManager.selectedTab?.canGoForward == true) { tabManager.selectedTab?.webView.goForward() }
            BrowserToolbarButton(systemName: tabManager.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", helpText: tabManager.selectedTab?.isExamProtected == true ? "Reload disabled by Exam Protection" : (tabManager.selectedTab?.isLoading == true ? "Stop" : "Reload"), isEnabled: tabManager.selectedTab?.isLoading == true || tabManager.selectedTab?.isExamProtected != true) {
                if tabManager.selectedTab?.isLoading == true { tabManager.selectedTab?.webView.stopLoading() }
                else if tabManager.selectedTab?.isExamProtected != true { tabManager.selectedTab?.webView.reload() }
            }
            HStack(spacing: LeafSpacing.small) {
                Image(systemName: tabManager.selectedTab?.url?.scheme == "https" ? "lock.fill" : "globe")
                    .font(.caption).foregroundStyle(tabManager.selectedTab?.url?.scheme == "https" ? LeafColors.secure : .secondary)
                TextField("Search Google or enter an address", text: $addressText)
                    .focused($omniboxFocused).textFieldStyle(.plain).font(.system(size: 13))
                    .onSubmit(submitAddress)
            }
            .padding(.horizontal, LeafSpacing.medium).frame(height: 36)
            .background(LeafColors.omnibox, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(LeafColors.border) }
            .shadow(color: .black.opacity(0.12), radius: 5, y: 1)
            BrowserToolbarButton(systemName: tabManager.selectedTab?.isExamProtected == true ? "shield.fill" : "shield", helpText: "Exam Protection") {
                guard let tab = tabManager.selectedTab else { return }
                examProtection.protect(tab, enabled: !tab.isExamProtected)
            }
            BrowserToolbarButton(systemName: "gauge.with.dots.needle.67percent", helpText: "Performance") { showInspector = true }
            BrowserToolbarButton(systemName: "arrow.down.circle", helpText: "Downloads") { showDownloads = true }
            BrowserToolbarButton(systemName: libraryManager.isBookmarked(tabManager.selectedTab?.url) ? "star.fill" : "star", helpText: "Bookmark This Page") {
                guard let tab = tabManager.selectedTab else { return }
                libraryManager.toggleBookmark(title: tab.title, url: tab.url)
            }
            BrowserToolbarButton(systemName: "play.circle", helpText: "Media") { showMedia = true }
            BrowserToolbarButton(systemName: "slider.vertical.3", helpText: "Equalizer") { showEqualizer = true }
            pageMenu
        }
        .padding(.horizontal, LeafSpacing.medium).padding(.vertical, 7)
        .background(Color.black.opacity(0.12))
        .background {
            Button("") { omniboxFocused = true }.keyboardShortcut("l", modifiers: .command).hidden()
        }
    }

    private var findBar: some View {
        FindBarView(text: $findText, result: findResult,
                    previous: { find(backwards: true) }, next: { find(backwards: false) },
                    close: { showFindBar = false; findText = ""; findResult = "" })
    }

    private var pageMenu: some View {
        BrowserPageMenu(
            zoomPercent: Int((tabManager.selectedTab?.webView.pageZoom ?? 1) * 100),
            newTab: { tabManager.createTab() }, find: { showFindBar = true },
            zoomIn: { changeZoom(by: 0.1) }, zoomOut: { changeZoom(by: -0.1) },
            actualSize: { tabManager.selectedTab?.webView.pageZoom = 1 },
            fullScreen: { NSApp.keyWindow?.toggleFullScreen(nil) },
            copyLink: copyCurrentLink, printPage: printCurrentPage,
            bookmarks: { showBookmarks = true }, history: { showHistory = true }, downloads: { showDownloads = true },
            permissions: { showPermissions = true }
        )
    }

    @ViewBuilder private var progress: some View {
        if tabManager.selectedTab?.isLoading == true {
            ProgressView(value: tabManager.selectedTab?.estimatedProgress ?? 0).progressViewStyle(.linear).tint(LeafColors.accent).frame(height: 2)
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { tabManager.selectedTab?.navigationError != nil }, set: { if !$0 { tabManager.selectedTab?.navigationError = nil } })
    }

    private func submitAddress() {
        guard tabManager.selectedTab?.isExamProtected != true else { return }
        if !tabManager.navigateSelected(to: addressText) { tabManager.selectedTab?.navigationError = .invalidAddress }
    }

    private func syncAddress() { addressText = tabManager.selectedTab?.url?.absoluteString ?? "" }

    private func validateConnectivity() {
        guard !validatingNetwork else { return }
        validatingNetwork = true
        Task { _ = await ConnectivityProbe().validate(); validatingNetwork = false }
    }

    private func find(backwards: Bool) {
        guard !findText.isEmpty, let webView = tabManager.selectedTab?.webView else { findResult = ""; return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(findText, configuration: configuration) { result in
            findResult = result.matchFound ? "Found" : "0/0"
        }
    }

    private func changeZoom(by amount: Double) {
        guard let webView = tabManager.selectedTab?.webView else { return }
        webView.pageZoom = min(max(webView.pageZoom + amount, 0.5), 3)
    }

    private func copyCurrentLink() {
        guard let value = tabManager.selectedTab?.url?.absoluteString else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func printCurrentPage() {
        guard let webView = tabManager.selectedTab?.webView else { return }
        webView.printOperation(with: NSPrintInfo.shared).run()
    }

    private func selectWorkspace(_ id: UUID) {
        workspaceManager.selectWorkspace(id: id)
        let workspace = workspaceManager.selectedWorkspace
        if let selected = workspace?.selectedTabID, workspace?.tabIDs.contains(selected) == true { tabManager.selectTab(id: selected) }
        else if let first = workspace?.tabIDs.first { tabManager.selectTab(id: first) }
    }

    private func openLibraryURL(_ url: URL) {
        if tabManager.selectedTab?.url == nil { tabManager.selectedTab?.load(url) }
        else { tabManager.createTab(opening: url) }
    }
}
