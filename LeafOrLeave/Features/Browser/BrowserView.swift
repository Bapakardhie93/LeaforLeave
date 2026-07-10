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
    @State private var addressText = ""
    @State private var showInspector = false
    @State private var validatingNetwork = false
    @State private var showDownloads = false
    @State private var showMedia = false
    @State private var showEqualizer = false
    @State private var equalizer = EqualizerViewModel()
    @FocusState private var omniboxFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
          if settings.value.showSidebar { BrowserSidebarView(workspaces: workspaceManager, downloads: downloadManager, network: networkMonitor, select: selectWorkspace); Divider() }
          VStack(spacing: 0) {
            TabBarView(manager: tabManager, visibleTabIDs: Set(workspaceManager.selectedWorkspace?.tabIDs ?? []))
            toolbar
            progress
            content
          }
        }
        .background(LeafColors.background)
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
            .background(LeafColors.omnibox, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LeafColors.border) }
            BrowserToolbarButton(systemName: tabManager.selectedTab?.isExamProtected == true ? "shield.fill" : "shield", helpText: "Exam Protection") {
                guard let tab = tabManager.selectedTab else { return }
                examProtection.protect(tab, enabled: !tab.isExamProtected)
            }
            BrowserToolbarButton(systemName: "gauge.with.dots.needle.67percent", helpText: "Performance") { showInspector = true }
            BrowserToolbarButton(systemName: "arrow.down.circle", helpText: "Downloads") { showDownloads = true }
            BrowserToolbarButton(systemName: "play.circle", helpText: "Media") { showMedia = true }
            BrowserToolbarButton(systemName: "slider.vertical.3", helpText: "Equalizer") { showEqualizer = true }
        }
        .padding(.horizontal, LeafSpacing.medium).padding(.vertical, LeafSpacing.small)
        .background(.ultraThinMaterial)
        .background {
            Button("") { omniboxFocused = true }.keyboardShortcut("l", modifiers: .command).hidden()
        }
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

    private func selectWorkspace(_ id: UUID) {
        workspaceManager.selectWorkspace(id: id)
        let workspace = workspaceManager.selectedWorkspace
        if let selected = workspace?.selectedTabID, workspace?.tabIDs.contains(selected) == true { tabManager.selectTab(id: selected) }
        else if let first = workspace?.tabIDs.first { tabManager.selectTab(id: first) }
    }
}
