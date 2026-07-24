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
    @State private var showTabSearch = false
    @State private var showDeveloperConsole = false
    @State private var downloadToastID: UUID?
    @State private var dismissDownloadToastTask: Task<Void, Never>?
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
            toolbar
            TabBarView(manager: tabManager,
                       visibleTabIDs: Set(workspaceManager.selectedWorkspace?.tabIDs ?? []),
                       compact: settings.value.compactTabs || settings.value.density == .compact,
                       showFavicons: settings.value.showFavicons,
                       showMediaIndicators: settings.value.showMediaIndicators,
                       animationStyle: settings.value.animationStyle,
                       reservesWindowControls: false,
                       searchTabs: { showTabSearch.toggle() })
                .popover(isPresented: $showTabSearch, arrowEdge: .top) {
                    TabSearchView(manager: tabManager,
                                  visibleTabIDs: Set(workspaceManager.selectedWorkspace?.tabIDs ?? [])) { id in
                        tabManager.selectTab(id: id)
                        showTabSearch = false
                    }
                }
            progress
            ZStack(alignment: .topTrailing) {
              content
              if showFindBar { findBar.padding(.top, 10).padding(.trailing, 14) }
              if let record = downloadToastRecord {
                  DownloadToastView(record: record,
                                    openDownloads: {
                                        showDownloads = true
                                        dismissDownloadToast()
                                    },
                                    dismiss: dismissDownloadToast)
                      .padding(.top, showFindBar ? 72 : 14)
                      .padding(.trailing, 14)
                      .transition(.move(edge: .trailing).combined(with: .opacity))
                      .zIndex(2)
              }
            }
          }
        }
        .background(LeafColors.background)
        .background { Button("") { showFindBar = true }.keyboardShortcut("f", modifiers: .command).hidden() }
        .preferredColorScheme(preferredColorScheme)
        .tint(accentColor)
        .onAppear {
            syncPerformanceSettings()
            activateWorkspace(workspaceManager.selectedWorkspaceID)
            syncAddress()
        }
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
        .sheet(isPresented: $showInspector) {
            BrowserInspectorView(manager: tabManager, suspension: suspensionManager, settings: settings)
        }
        .sheet(isPresented: $showDownloads) { DownloadsListView(manager: downloadManager) }
        .sheet(isPresented: $showBookmarks) { LibraryListView(manager: libraryManager, kind: .bookmarks, open: openLibraryURL) }
        .sheet(isPresented: $showHistory) { LibraryListView(manager: libraryManager, kind: .history, open: openLibraryURL) }
        .sheet(isPresented: $showPermissions) { PermissionsView() }
        .sheet(isPresented: $showDeveloperConsole) { DeveloperConsoleView(tab: tabManager.selectedTab) }
        .popover(isPresented: $showMedia) { MiniMediaPanel(coordinator: mediaCoordinator) { tabManager.selectTab(id: $0) } }
        .sheet(isPresented: $showEqualizer) { EqualizerView(model: equalizer) { if let webView = tabManager.selectedTab?.webView { equalizer.apply(to: webView) } } }
        .onChange(of: workspaceManager.selectedWorkspaceID) { _, id in activateWorkspace(id) }
        .onChange(of: tabManager.tabs.map(\.id)) { _, ids in synchronizeWorkspaceTabs(ids) }
        .onChange(of: tabManager.selectedTabID) { _, id in workspaceManager.rememberSelection(id) }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if !connected, let tab = tabManager.selectedTab, tab.isExamProtected { Task { await examProtection.snapshot(tab) } }
        }
        .onChange(of: downloadManager.records.first?.id) { _, id in
            guard let id else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) { downloadToastID = id }
            scheduleDownloadToastDismiss(after: 8)
        }
        .onChange(of: downloadToastRecord?.status) { _, status in
            guard status == .completed || status == .failed || status == .cancelled else { return }
            scheduleDownloadToastDismiss(after: status == .completed ? 4 : 7)
        }
        .onChange(of: settings.value.webInspector) { _, enabled in
            tabManager.tabs.forEach { $0.webView.isInspectable = enabled && settings.value.developerMode }
        }
        .onChange(of: performanceConfiguration) { _, _ in
            syncPerformanceSettings()
        }
    }

    private var performanceConfiguration: PerformanceConfiguration {
        PerformanceConfiguration(
            enabled: settings.value.smartSuspension,
            idleTimeout: settings.value.idleTimeout,
            aggressiveness: settings.value.suspensionAggressiveness,
            keepsMediaAlive: settings.value.keepMediaAlive,
            keepsExamTabsAlive: settings.value.keepExamTabsAlive,
            keepsPinnedTabsAlive: settings.value.keepPinnedTabsAlive
        )
    }

    private func syncPerformanceSettings() {
        suspensionManager.apply(settings.value)
    }

    @ViewBuilder private var content: some View {
        if let tab = tabManager.selectedTab {
            if tab.url == nil && !tab.isLoading {
                NewTabPageView(library: libraryManager,
                               workspaceName: workspaceManager.selectedWorkspace?.name ?? "Workspace",
                               isConnected: networkMonitor.isConnected,
                               showQuickLinks: settings.value.showQuickLinks,
                               showRecentActivity: settings.value.showRecentActivity,
                               quickLinks: settings.value.quickLinks) { input in
                    addressText = input
                    submitAddress()
                }
            } else {
                ZStack(alignment: .top) {
                    if tab.isPictureInPicture {
                        VStack(spacing: 14) {
                            Image(systemName: "pip.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(LeafColors.accent)
                            Text("Playing in the LeafOrLeave mini-player")
                                .font(.headline)
                            Text("Close the floating player to return the page to this tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        WebViewContainer(webView: tab.webView)
                    }
                    if let offer = tab.passwordSaveOffer {
                        PasswordSavePrompt(
                            offer: offer,
                            save: tab.acceptPasswordSaveOffer,
                            dismiss: tab.dismissPasswordSaveOffer
                        )
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(4)
                    } else if !tab.passwordAutofillAccounts.isEmpty,
                       let host = tab.passwordAutofillHost {
                        PasswordAutofillAccountPicker(
                            host: host,
                            accounts: tab.passwordAutofillAccounts,
                            select: tab.selectPasswordAutofillAccount,
                            dismiss: tab.dismissPasswordAutofillAccounts
                        )
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(3)
                    }
                    if tab.isExamProtected, !networkMonitor.isConnected, let since = networkMonitor.offlineSince {
                        RecoveryOverlayView(since: since) { validateConnectivity() }
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            toolbarRow(showsAllActions: true)
            toolbarRow(showsAllActions: false)
        }
        .frame(height: BrowserChromeMetrics.toolbarHeight)
        .padding(.horizontal, 10)
        .background {
            LinearGradient(
                colors: [Color.primary.opacity(0.045), Color.primary.opacity(0.018)],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
        }
        .overlay(alignment: .bottom) { Divider().opacity(0.32) }
        .background {
            Button("") { omniboxFocused = true }.keyboardShortcut("l", modifiers: .command).hidden()
        }
        .background {
            Button("") { showTabSearch.toggle() }.keyboardShortcut("a", modifiers: [.command, .shift]).hidden()
        }
    }

    private func toolbarRow(showsAllActions: Bool) -> some View {
        HStack(spacing: 8) {
            if !settings.value.showSidebar {
                Color.clear
                    .frame(width: BrowserChromeMetrics.trafficLightReserve, height: 1)
                    .accessibilityHidden(true)
                BrowserToolbarButton(systemName: "sidebar.left", helpText: "Show Sidebar (⌘⇧S)") {
                    withAnimation(.easeInOut(duration: 0.18)) { settings.value.showSidebar = true }
                }
            }

            navigationControls

            if settings.value.showHomeButton {
                BrowserToolbarButton(systemName: "house", helpText: "Home", drawsBackground: true) {
                    openWorkspaceHome()
                }
            }

            Spacer(minLength: 2)
            omnibox
                .frame(minWidth: showsAllActions ? 300 : 240, idealWidth: 540, maxWidth: 660)
                .layoutPriority(1)
            Spacer(minLength: 2)

            if showsAllActions {
                fullToolbarActions
            } else {
                compactToolbarActions
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 0) {
            BrowserToolbarButton(
                systemName: "chevron.left",
                helpText: "Back",
                isEnabled: tabManager.selectedTab?.canGoBack == true
            ) {
                tabManager.selectedTab?.webView.goBack()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1, height: 16)
            BrowserToolbarButton(
                systemName: "chevron.right",
                helpText: "Forward",
                isEnabled: tabManager.selectedTab?.canGoForward == true
            ) {
                tabManager.selectedTab?.webView.goForward()
            }
        }
        .padding(.horizontal, 2)
        .background(LeafColors.chromeSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var omnibox: some View {
        HStack(spacing: 8) {
            Image(systemName: omniboxSecurityIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(omniboxSecurityColor)
                .frame(width: 16)

            TextField("Search Google or enter an address", text: $addressText)
                .focused($omniboxFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1)
                .onSubmit(submitAddress)
                .onTapGesture {
                    if omniboxFocused {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }

            if !addressText.isEmpty && omniboxFocused {
                Button { addressText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear address")
            } else {
                Button(action: reloadOrStop) {
                    Image(systemName: tabManager.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(reloadIsEnabled ? Color.secondary : Color.secondary.opacity(0.35))
                .disabled(!reloadIsEnabled)
                .cursorHelp(reloadHelpText)
                .accessibilityLabel(reloadHelpText)
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 5)
        .frame(height: BrowserChromeMetrics.omniboxHeight)
        .background(LeafColors.omnibox, in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.omniboxCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrowserChromeMetrics.omniboxCornerRadius, style: .continuous)
                .strokeBorder(
                    omniboxFocused ? accentColor.opacity(0.78) : LeafColors.border,
                    lineWidth: omniboxFocused ? 1.5 : 1
                )
        }
        .shadow(color: omniboxFocused ? accentColor.opacity(0.16) : .black.opacity(0.08), radius: 5, y: 1)
    }

    private var fullToolbarActions: some View {
        HStack(spacing: 8) {
            if settings.value.showNetworkHUD {
                NetworkStatusButton(network: networkMonitor)
                    .fixedSize()
            }
            HStack(spacing: 2) {
                examToolbarButton
                downloadsToolbarButton
                bookmarkToolbarButton
                if mediaCoordinator.mediaTabs.isEmpty == false {
                    BrowserToolbarButton(systemName: "play.circle.fill", helpText: "Media") {
                        showMedia = true
                    }
                }
                if settings.value.developerMode && settings.value.showTerminalShortcut {
                    BrowserToolbarButton(systemName: "terminal", helpText: "Open Terminal") {
                        openTerminal()
                    }
                }
                if settings.value.developerMode {
                    BrowserToolbarButton(systemName: "ladybug", helpText: "Developer Console") {
                        openDeveloperConsole()
                    }
                }
                pageMenu
            }
            .padding(.horizontal, 2)
            .background(LeafColors.chromeSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055))
            }
        }
    }

    private var compactToolbarActions: some View {
        HStack(spacing: 2) {
            examToolbarButton
            downloadsToolbarButton
            if hasCompactToolbarExtras {
                compactExtrasMenu
            }
            pageMenu
        }
        .padding(.horizontal, 2)
        .background(LeafColors.chromeSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055))
        }
    }

    @ViewBuilder private var examToolbarButton: some View {
        if settings.value.showExamButton {
            BrowserToolbarButton(
                systemName: tabManager.selectedTab?.isExamProtected == true ? "shield.fill" : "shield",
                helpText: "Exam Protection"
            ) {
                toggleExamProtection()
            }
        }
    }

    @ViewBuilder private var downloadsToolbarButton: some View {
        if settings.value.showDownloadsButton {
            DownloadToolbarButton(
                activeCount: activeDownloadCount,
                latestProgress: downloadManager.records.first(where: { $0.status == .downloading })?.progress ?? 0
            ) {
                showDownloads = true
            }
        }
    }

    @ViewBuilder private var bookmarkToolbarButton: some View {
        if settings.value.showBookmarksButton {
            BrowserToolbarButton(
                systemName: libraryManager.isBookmarked(tabManager.selectedTab?.url) ? "star.fill" : "star",
                helpText: "Bookmark This Page"
            ) {
                toggleBookmark()
            }
        }
    }

    private var compactExtrasMenu: some View {
        Menu {
            if settings.value.showBookmarksButton {
                Button(action: toggleBookmark) {
                    Label(
                        libraryManager.isBookmarked(tabManager.selectedTab?.url) ? "Remove Bookmark" : "Bookmark This Page",
                        systemImage: libraryManager.isBookmarked(tabManager.selectedTab?.url) ? "star.slash" : "star"
                    )
                }
            }
            if mediaCoordinator.mediaTabs.isEmpty == false {
                Button { showMedia = true } label: {
                    Label("Media Controls", systemImage: "play.circle")
                }
            }
            if settings.value.showNetworkHUD {
                Button { networkMonitor.refreshLatency() } label: {
                    Label(networkStatusText, systemImage: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                }
            }
            if settings.value.developerMode && settings.value.showTerminalShortcut {
                Button(action: openTerminal) {
                    Label("Open Terminal", systemImage: "terminal")
                }
            }
            if settings.value.developerMode {
                Button(action: openDeveloperConsole) {
                    Label("Developer Console", systemImage: "ladybug")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .medium))
                .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: BrowserChromeMetrics.controlSize)
        .cursorHelp("More toolbar actions")
        .accessibilityLabel("More toolbar actions")
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
            permissions: { showPermissions = true },
            performance: { showInspector = true }, equalizer: { showEqualizer = true }
        )
    }

    private var progress: some View {
        ZStack {
            Color.clear
            if tabManager.selectedTab?.isLoading == true {
                ProgressView(value: tabManager.selectedTab?.estimatedProgress ?? 0)
                    .progressViewStyle(.linear)
                    .tint(LeafColors.accent)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(tabManager.selectedTab?.isLoading != true)
    }

    private var omniboxSecurityIcon: String {
        guard let url = tabManager.selectedTab?.url else { return "magnifyingglass" }
        return url.scheme == "https" ? "lock.fill" : "globe"
    }

    private var omniboxSecurityColor: Color {
        tabManager.selectedTab?.url?.scheme == "https" ? LeafColors.secure : .secondary
    }

    private var reloadIsEnabled: Bool {
        tabManager.selectedTab?.isLoading == true || tabManager.selectedTab?.isExamProtected != true
    }

    private var reloadHelpText: String {
        if tabManager.selectedTab?.isExamProtected == true { return "Reload disabled by Exam Protection" }
        return tabManager.selectedTab?.isLoading == true ? "Stop loading" : "Reload"
    }

    private var networkStatusText: String {
        guard networkMonitor.isConnected else { return "Network Offline" }
        if let latency = networkMonitor.latencyMS { return "Network: \(latency) ms" }
        return "Network Connected"
    }

    private var hasCompactToolbarExtras: Bool {
        settings.value.showBookmarksButton
            || settings.value.showNetworkHUD
            || mediaCoordinator.mediaTabs.isEmpty == false
            || settings.value.developerMode
    }

    private func reloadOrStop() {
        if tabManager.selectedTab?.isLoading == true {
            tabManager.selectedTab?.webView.stopLoading()
        } else if tabManager.selectedTab?.isExamProtected != true {
            tabManager.selectedTab?.webView.reload()
        }
    }

    private func toggleExamProtection() {
        guard let tab = tabManager.selectedTab else { return }
        examProtection.protect(tab, enabled: !tab.isExamProtected)
    }

    private func toggleBookmark() {
        guard let tab = tabManager.selectedTab else { return }
        libraryManager.toggleBookmark(title: tab.title, url: tab.url)
    }

    private func openDeveloperConsole() {
        tabManager.selectedTab?.webView.isInspectable = settings.value.webInspector
        showDeveloperConsole = true
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
        LeafClipboard.copy(value)
    }

    private func printCurrentPage() {
        guard let webView = tabManager.selectedTab?.webView else { return }
        webView.printOperation(with: NSPrintInfo.shared).run()
    }

    private func selectWorkspace(_ id: UUID) {
        workspaceManager.selectWorkspace(id: id)
        activateWorkspace(id)
    }

    private func activateWorkspace(_ id: UUID?) {
        guard let id else { return }
        let existingTabIDs = tabManager.tabs.map(\.id)
        let validTabIDs = Set(existingTabIDs)
        workspaceManager.reconcileTabs(existingTabIDs, assigningUnownedTo: id)
        guard let workspace = workspaceManager.workspaces.first(where: { $0.id == id }) else { return }

        if let selected = workspace.selectedTabID, validTabIDs.contains(selected) {
            tabManager.selectTab(id: selected)
        } else if let first = workspace.tabIDs.first(where: validTabIDs.contains) {
            tabManager.selectTab(id: first)
        } else {
            let tab = tabManager.createTab()
            workspaceManager.moveTab(tab.id, to: id)
        }
    }

    private func synchronizeWorkspaceTabs(_ ids: [UUID]) {
        workspaceManager.reconcileTabs(ids, assigningUnownedTo: workspaceManager.selectedWorkspaceID)
        guard let workspace = workspaceManager.selectedWorkspace else { return }
        let validTabIDs = Set(ids)

        if let active = tabManager.selectedTabID, workspace.tabIDs.contains(active) {
            workspaceManager.rememberSelection(active)
        } else if let selected = workspace.selectedTabID, validTabIDs.contains(selected) {
            tabManager.selectTab(id: selected)
        } else if let first = workspace.tabIDs.first(where: validTabIDs.contains) {
            tabManager.selectTab(id: first)
        } else {
            let tab = tabManager.createTab()
            workspaceManager.moveTab(tab.id, to: workspace.id)
        }
    }

    private func openLibraryURL(_ url: URL) {
        if tabManager.selectedTab?.url == nil { tabManager.selectedTab?.load(url) }
        else { tabManager.createTab(opening: url) }
    }

    private var activeDownloadCount: Int {
        downloadManager.records.filter { $0.status == .downloading }.count
    }

    private var downloadToastRecord: DownloadRecord? {
        guard let downloadToastID else { return nil }
        return downloadManager.records.first { $0.id == downloadToastID }
    }

    private func scheduleDownloadToastDismiss(after seconds: Double) {
        dismissDownloadToastTask?.cancel()
        dismissDownloadToastTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) { downloadToastID = nil }
        }
    }

    private func dismissDownloadToast() {
        dismissDownloadToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { downloadToastID = nil }
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.value.appearance {
        case .system: nil
        case .light: .light
        case .dark, .graphiteDark: .dark
        }
    }

    private var accentColor: Color {
        if let workspaceAccent = workspaceManager.selectedWorkspace?.accentName {
            switch workspaceAccent {
            case "blue": return .blue
            case "teal": return .teal
            case "green": return .green
            case "orange": return .orange
            case "pink": return .pink
            default: return LeafColors.accent
            }
        }
        switch settings.value.accent {
        case .violet: return LeafColors.accent
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        }
    }

    private func openTerminal() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openWorkspaceHome() {
        guard let value = workspaceManager.selectedWorkspace?.homePage,
              !value.isEmpty, let url = URLResolver().resolve(value) else {
            tabManager.createTab()
            return
        }
        if let tab = tabManager.selectedTab, tab.url != nil { tab.load(url) }
        else { tabManager.selectedTab?.load(url) }
    }
}

private struct PasswordSavePrompt: View {
    let offer: PasswordSaveOffer
    let save: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: offer.isUpdate ? "key.radiowaves.forward.fill" : "key.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(LeafColors.accent, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.isUpdate ? "Update saved password?" : "Save this password?")
                        .font(LeafTypography.bodyEmphasized)
                    Text(offer.host)
                        .font(LeafTypography.supporting)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Not now")
            }

            HStack(spacing: 9) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(LeafColors.accent)
                Text(offer.username)
                    .font(LeafTypography.body)
                    .lineLimit(1)
                Spacer()
                Label("macOS Keychain", systemImage: "lock.shield")
                    .font(LeafTypography.sectionLabel)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))

            HStack {
                Spacer()
                Button("Not Now", action: dismiss)
                Button(offer.isUpdate ? "Update Password" : "Save Password", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(LeafColors.accent)
            }
        }
        .padding(14)
        .frame(width: 390)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(offer.isUpdate ? "Update saved password" : "Save password")
    }
}

private struct PasswordAutofillAccountPicker: View {
    let host: String
    let accounts: [PasswordAutofillAccount]
    let select: (UUID) -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "key.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(LeafColors.accent, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose an account")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Autofill for \(host)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Not now")
            }
            .padding(12)

            Divider()

            ForEach(accounts) { account in
                Button {
                    select(account.id)
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LeafColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.username)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Saved account")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(LeafColors.accent)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Autofill \(account.username)")

                if account.id != accounts.last?.id {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
    }
}

private struct PerformanceConfiguration: Equatable {
    let enabled: Bool
    let idleTimeout: Double
    let aggressiveness: Double
    let keepsMediaAlive: Bool
    let keepsExamTabsAlive: Bool
    let keepsPinnedTabsAlive: Bool
}
