import AppKit
import SwiftUI
import WebKit

private enum BrowserLibraryPanel: String, Identifiable {
    case downloads, bookmarks, history
    var id: String { rawValue }
}

struct BrowserView: View {
    let tabManager: TabManager
    let window: BrowserWindowState
    let networkMonitor: NetworkMonitor
    let examProtection: ExamProtectionManager
    let suspensionManager: TabSuspensionManager
    let workspaceManager: WorkspaceManager
    let downloadManager: DownloadManager
    let mediaCoordinator: MediaCoordinator
    let settings: SettingsStore
    let libraryManager: LibraryManager
    @Environment(\.openWindow) private var openWindow
    @State private var addressText = ""
    @State private var showInspector = false
    @State private var validatingNetwork = false
    @State private var activeLibraryPanel: BrowserLibraryPanel?
    @State private var showMedia = false
    @State private var showEqualizer = false
    @State private var showFindBar = false
    @State private var findText = ""
    @State private var findResult = ""
    @State private var showPermissions = false
    @State private var showTabSearch = false
    @State private var showDeveloperConsole = false
    @State private var splitMenuHovered = false
    @State private var downloadToastID: UUID?
    @State private var dismissDownloadToastTask: Task<Void, Never>?
    @State private var equalizer = EqualizerViewModel()
    @State private var omniboxFocused = false
    @State private var omniboxSelectionRequest = 0

    var body: some View {
        HStack(spacing: 0) {
          if settings.value.showSidebar {
            BrowserSidebarView(workspaces: workspaceManager, selectedWorkspaceID: window.workspaceID,
                               downloads: downloadManager, network: networkMonitor,
                               select: selectWorkspace, newPrivateTab: newPrivateTab,
                               showBookmarks: { presentLibraryPanel(.bookmarks) },
                               showHistory: { presentLibraryPanel(.history) },
                               showDownloads: { presentLibraryPanel(.downloads) },
                               collapse: { withAnimation(.easeInOut(duration: 0.18)) { settings.value.showSidebar = false } })
            Divider()
          }
          VStack(spacing: 0) {
            toolbar
            if settings.value.tabPlacement == .top {
                horizontalTabBar
            }
            progress
            HStack(spacing: 0) {
                if settings.value.tabPlacement == .left {
                    verticalTabBar
                }
                browserViewport
            }
          }
        }
        .background(browserBackground)
        .background {
            Button("") { showFindBar = true }
                .keyboardShortcut(shortcut(.findInPage).keyEquivalent,
                                  modifiers: shortcut(.findInPage).modifiers.eventModifiers)
                .hidden()
        }
        .leafAppearance(settings.value.appearance)
        .tint(accentColor)
        .environment(\.leafAccentColor, accentColor)
        .environment(\.leafToolbarIconSize, toolbarIconSize)
        .onAppear {
            tabManager.activateWindow(id: window.id)
            if let workspaceID = window.workspaceID ?? workspaceManager.workspaces.first?.id {
                window.workspaceID = workspaceID
                workspaceManager.selectWorkspace(id: workspaceID)
            }
            syncPerformanceSettings()
            activateWorkspace(window.workspaceID)
            syncAddress()
        }
        .onChange(of: window.focusedTabID) { _, _ in syncAddress() }
        .onChange(of: focusedTab?.url) { _, _ in syncAddress() }
        .onKeyPress(.tab, phases: .down) { event in
            guard event.modifiers.contains(.control) else { return .ignored }
            tabManager.selectRelative(event.modifiers.contains(.shift) ? -1 : 1, in: window.id)
            return .handled
        }
        .onKeyPress(phases: .down) { event in
            guard event.modifiers == .command, let number = Int(event.characters), (1...9).contains(number) else { return .ignored }
            tabManager.selectTab(number: number, in: window.id)
            return .handled
        }
        .sheet(isPresented: $showInspector) {
            BrowserInspectorView(manager: tabManager, suspension: suspensionManager, settings: settings)
        }
        .sheet(item: $activeLibraryPanel) { panel in
            switch panel {
            case .downloads:
                DownloadsListView(manager: downloadManager)
            case .bookmarks:
                LibraryListView(manager: libraryManager, kind: .bookmarks, open: openLibraryURL)
            case .history:
                LibraryListView(manager: libraryManager, kind: .history, open: openLibraryURL)
            }
        }
        .sheet(isPresented: $showPermissions) { PermissionsView() }
        .sheet(isPresented: $showDeveloperConsole) { DeveloperConsoleView(tab: focusedTab) }
        .popover(isPresented: $showMedia) { MiniMediaPanel(coordinator: mediaCoordinator) { tabManager.selectTab(id: $0, in: window.id) } }
        .sheet(isPresented: $showEqualizer) { EqualizerView(model: equalizer) { if let webView = focusedTab?.webView { equalizer.apply(to: webView) } } }
        .onChange(of: window.workspaceID) { oldID, id in
            if oldID != id { window.exitSplit() }
            activateWorkspace(id)
        }
        .onChange(of: window.tabIDs) { _, ids in synchronizeWorkspaceTabs(ids) }
        .onChange(of: window.focusedTabID) { _, id in workspaceManager.rememberSelection(id) }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if !connected, let tab = focusedTab, tab.isExamProtected { Task { await examProtection.snapshot(tab) } }
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
        .onChange(of: developerConfiguration) { _, _ in tabManager.applyDeveloperSettings() }
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

    private var developerConfiguration: DeveloperConfiguration {
        DeveloperConfiguration(
            developerMode: settings.value.developerMode,
            webInspector: settings.value.webInspector,
            captureConsoleLogs: settings.value.captureConsoleLogs
        )
    }

    private func syncPerformanceSettings() {
        suspensionManager.apply(settings.value)
    }

    private var horizontalTabBar: some View {
        TabBarView(manager: tabManager, window: window,
                   visibleTabIDs: Set(selectedWorkspace?.tabIDs ?? []),
                   compact: settings.value.compactTabs || settings.value.density == .compact,
                   showFavicons: settings.value.showFavicons,
                   showMediaIndicators: settings.value.showMediaIndicators,
                   animationStyle: settings.value.animationStyle,
                   reservesWindowControls: false,
                   newTabShortcut: shortcut(.newTab).display,
                   searchTabsShortcut: shortcut(.searchTabs).display,
                   searchTabs: { showTabSearch.toggle() },
                   detachTab: detachTab,
                   openInSplit: { tabManager.addToSplit(tabID: $0, in: window.id) })
            .popover(isPresented: $showTabSearch, arrowEdge: .top) { tabSearchPopover }
    }

    private var verticalTabBar: some View {
        VerticalTabBarView(manager: tabManager, window: window,
                           visibleTabIDs: Set(selectedWorkspace?.tabIDs ?? []),
                           compact: settings.value.compactTabs || settings.value.density == .compact,
                           showFavicons: settings.value.showFavicons,
                           showMediaIndicators: settings.value.showMediaIndicators,
                           newTabShortcut: shortcut(.newTab).display,
                           searchTabsShortcut: shortcut(.searchTabs).display,
                           searchTabs: { showTabSearch.toggle() },
                           detachTab: detachTab,
                           openInSplit: { tabManager.addToSplit(tabID: $0, in: window.id) })
            .popover(isPresented: $showTabSearch, arrowEdge: .top) { tabSearchPopover }
    }

    private var tabSearchPopover: some View {
        TabSearchView(manager: tabManager,
                      visibleTabIDs: Set(selectedWorkspace?.tabIDs ?? []),
                      selectedTabID: window.focusedTabID) { id in
            tabManager.selectTab(id: id, in: window.id)
            showTabSearch = false
        }
    }

    private var browserViewport: some View {
        ZStack(alignment: .topTrailing) {
            content
            if showFindBar { findBar.padding(.top, 10).padding(.trailing, 14) }
            if let record = downloadToastRecord {
                DownloadToastView(record: record,
                                  openDownloads: {
                                      presentLibraryPanel(.downloads)
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

    @ViewBuilder private var content: some View {
        let visibleTabs = window.visibleTabIDs.compactMap(tabManager.tab(id:))
        if visibleTabs.count > 1 {
            BrowserSplitLayout(
                tabs: visibleTabs,
                fractions: window.splitFractions,
                focusedTabID: window.focusedTabID,
                accentColor: accentColor,
                focus: { tabManager.focusTab(id: $0, in: window.id) },
                remove: { tabManager.removeFromSplit(tabID: $0, in: window.id) },
                commitFractions: { tabManager.commitSplitFractions($0, in: window.id) }
            ) { tab in
                tabContent(tab)
            }
        } else if let tab = visibleTabs.first ?? focusedTab {
            tabContent(tab)
        }
    }

    @ViewBuilder private func tabContent(_ tab: BrowserTab) -> some View {
        if let error = tab.navigationError, !tab.isLoading {
            navigationFailure(error, for: tab)
        } else if tab.url == nil && !tab.isLoading {
            NewTabPageView(library: libraryManager,
                           workspaceName: selectedWorkspace?.name ?? "Workspace",
                           isConnected: networkMonitor.isConnected,
                           showQuickLinks: settings.value.showQuickLinks,
                           showRecentActivity: settings.value.showRecentActivity,
                           quickLinks: settings.value.quickLinks,
                           backgroundStyle: settings.value.newTabBackgroundStyle,
                           backgroundColor: browserBackground,
                           isPrivate: tab.isPrivate) { input in
                tabManager.focusTab(id: tab.id, in: window.id)
                addressText = input
                submitAddress()
            }
            .contentShape(Rectangle())
            .onTapGesture { tabManager.focusTab(id: tab.id, in: window.id) }
        } else {
            ZStack(alignment: .top) {
                if tab.isPictureInPicture {
                    VStack(spacing: 14) {
                        Image(systemName: "pip.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(accentColor)
                        Text("Playing in the LeafOrLeave mini-player")
                            .font(.headline)
                        Text("Close the floating player to return the page to this tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { tabManager.focusTab(id: tab.id, in: window.id) }
                } else {
                    WebViewContainer(webView: tab.webView) {
                        tabManager.focusTab(id: tab.id, in: window.id)
                    }
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
                } else if shouldShowOfflineOverlay(for: tab) {
                    BrowserFailureView(
                        error: nil,
                        address: tab.url?.absoluteString,
                        offlineSince: networkMonitor.offlineSince,
                        isRetrying: validatingNetwork,
                        primaryActionTitle: "Try Again",
                        primaryAction: { retryNavigation(for: tab) },
                        goBack: tab.canGoBack ? { _ = tab.navigateBack() } : nil
                    )
                    .transition(.opacity)
                    .zIndex(5)
                }
            }
        }
    }

    private func navigationFailure(
        _ error: BrowserNavigationError,
        for tab: BrowserTab
    ) -> some View {
        BrowserFailureView(
            error: error,
            address: tab.lastFailedURL?.absoluteString ?? tab.url?.absoluteString,
            offlineSince: error.failureKind == .offline ? networkMonitor.offlineSince : nil,
            isRetrying: validatingNetwork,
            primaryActionTitle: error == .invalidAddress ? "Edit Address" : "Try Again",
            primaryAction: {
                if error == .invalidAddress {
                    tab.navigationError = nil
                    focusOmnibox(selectingAll: true)
                } else {
                    retryNavigation(for: tab)
                }
            },
            goBack: tab.canGoBack ? { _ = tab.navigateBack() } : nil
        )
        .contentShape(Rectangle())
        .onTapGesture { tabManager.focusTab(id: tab.id, in: window.id) }
    }

    private func shouldShowOfflineOverlay(for tab: BrowserTab) -> Bool {
        guard settings.value.offlineOverlay,
              !networkMonitor.isConnected,
              let url = tab.url,
              !url.isFileURL else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            toolbarRow(showsAllActions: true)
            toolbarRow(showsAllActions: false)
        }
        .frame(height: toolbarHeight)
        .padding(.horizontal, toolbarHorizontalPadding)
        .background { toolbarBackground }
        .overlay(alignment: .bottom) { Divider().opacity(0.32).allowsHitTesting(false) }
        .background {
            Button("") { focusOmnibox(selectingAll: true) }
                .keyboardShortcut(shortcut(.focusAddress).keyEquivalent,
                                  modifiers: shortcut(.focusAddress).modifiers.eventModifiers)
                .hidden()
        }
        .background {
            Button("") { showTabSearch.toggle() }
                .keyboardShortcut(shortcut(.searchTabs).keyEquivalent,
                                  modifiers: shortcut(.searchTabs).modifiers.eventModifiers)
                .hidden()
        }
    }

    private func toolbarRow(showsAllActions: Bool) -> some View {
        HStack(spacing: 7) {
            if !settings.value.showSidebar {
                Color.clear
                    .frame(width: BrowserChromeMetrics.trafficLightReserve, height: 1)
                    .accessibilityHidden(true)
                BrowserToolbarButton(systemName: "sidebar.left",
                                     helpText: "Show Sidebar (\(shortcut(.toggleSidebar).display))") {
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
                isEnabled: focusedTab?.canGoBack == true
            ) {
                focusedTab?.navigateBack()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1, height: 16)
            BrowserToolbarButton(
                systemName: "chevron.right",
                helpText: "Forward",
                isEnabled: focusedTab?.canGoForward == true
            ) {
                focusedTab?.navigateForward()
            }
        }
        .padding(.horizontal, 2)
        .background(toolbarGroupColor, in: RoundedRectangle(cornerRadius: toolbarGroupCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
                .allowsHitTesting(false)
        }
    }

    private var omnibox: some View {
        HStack(spacing: 8) {
            Image(systemName: omniboxSecurityIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(omniboxSecurityColor)
                .frame(width: 16)

            OmniboxTextField(
                text: $addressText,
                isFocused: $omniboxFocused,
                selectionRequest: omniboxSelectionRequest,
                suggestion: { input in
                    focusedTab?.isPrivate == true ? nil : libraryManager.autocompleteSuggestion(for: input)
                },
                onSubmit: submitAddress
            )
            .frame(minHeight: 20)

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
                    Image(systemName: focusedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
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
                .allowsHitTesting(false)
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
                splitToolbarMenu
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
            .background(toolbarGroupColor, in: RoundedRectangle(cornerRadius: toolbarGroupCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055))
                    .allowsHitTesting(false)
            }
        }
    }

    private var compactToolbarActions: some View {
        HStack(spacing: 2) {
            splitToolbarMenu
            examToolbarButton
            downloadsToolbarButton
            if hasCompactToolbarExtras {
                compactExtrasMenu
            }
            pageMenu
        }
        .padding(.horizontal, 2)
        .background(toolbarGroupColor, in: RoundedRectangle(cornerRadius: toolbarGroupCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055))
                .allowsHitTesting(false)
        }
    }

    private var splitToolbarMenu: some View {
        Menu {
            if window.canAddSplit {
                let availableTabs = tabsAvailableForSplit
                if availableTabs.isEmpty {
                    Button("Open New Tab in Split") {
                        let tab = tabManager.createTab(activate: false, in: window.id)
                        tabManager.addToSplit(tabID: tab.id, in: window.id)
                    }
                } else {
                    ForEach(availableTabs) { tab in
                        Button {
                            tabManager.addToSplit(tabID: tab.id, in: window.id)
                        } label: {
                            Label(tab.title, systemImage: "rectangle.split.2x1")
                        }
                    }
                    Divider()
                    Button("Open New Tab in Split") {
                        let tab = tabManager.createTab(activate: false, in: window.id)
                        tabManager.addToSplit(tabID: tab.id, in: window.id)
                    }
                }
            } else {
                Text("Maximum of three panels reached")
            }
            if window.isSplit {
                Divider()
                Button("Exit Split Screen") { tabManager.exitSplit(in: window.id) }
            }
        } label: {
            ZStack {
                Color.clear
                Image(systemName: splitToolbarSymbol)
                    .font(.system(size: toolbarIconSize, weight: .medium))
            }
            .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
        .background(
            splitMenuHovered ? LeafColors.chromeHover : Color.clear,
            in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.toolbarControlCornerRadius, style: .continuous)
        )
        .onHover { splitMenuHovered = $0 }
        .cursorHelp(window.isSplit ? "Manage Split Screen" : "Open Split Screen")
        .accessibilityLabel(window.isSplit ? "Manage Split Screen" : "Open Split Screen")
    }

    private var tabsAvailableForSplit: [BrowserTab] {
        tabManager.tabs(in: window.id).filter {
            !window.visibleTabIDs.contains($0.id) && (selectedWorkspace?.tabIDs.contains($0.id) ?? true)
        }
    }

    private var splitToolbarSymbol: String {
        switch window.visibleTabIDs.count {
        case 3: "rectangle.split.3x1.fill"
        case 2: "rectangle.split.2x1.fill"
        default: "rectangle.split.2x1"
        }
    }

    @ViewBuilder private var examToolbarButton: some View {
        if settings.value.showExamButton {
            BrowserToolbarButton(
                systemName: focusedTab?.isExamProtected == true ? "shield.fill" : "shield",
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
                presentLibraryPanel(.downloads)
            }
        }
    }

    @ViewBuilder private var bookmarkToolbarButton: some View {
        if settings.value.showBookmarksButton {
            BrowserToolbarButton(
                systemName: libraryManager.isBookmarked(focusedTab?.url) ? "star.fill" : "star",
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
                        libraryManager.isBookmarked(focusedTab?.url) ? "Remove Bookmark" : "Bookmark This Page",
                        systemImage: libraryManager.isBookmarked(focusedTab?.url) ? "star.slash" : "star"
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
            ZStack {
                Color.clear
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: toolbarIconSize, weight: .medium))
            }
            .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
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
            zoomPercent: Int((focusedTab?.webView.pageZoom ?? 1) * 100),
            newTab: { tabManager.createTab(in: window.id) },
            newPrivateTab: newPrivateTab,
            find: { showFindBar = true },
            zoomIn: { changeZoom(by: 0.1) }, zoomOut: { changeZoom(by: -0.1) },
            actualSize: { focusedTab?.webView.pageZoom = 1 },
            fullScreen: { NSApp.keyWindow?.toggleFullScreen(nil) },
            copyLink: copyCurrentLink, printPage: printCurrentPage,
            bookmarks: { presentLibraryPanel(.bookmarks) },
            history: { presentLibraryPanel(.history) },
            downloads: { presentLibraryPanel(.downloads) },
            permissions: { showPermissions = true },
            performance: { showInspector = true }, equalizer: { showEqualizer = true }
        )
    }

    private var progress: some View {
        ZStack {
            Color.clear
            if focusedTab?.isLoading == true {
                ProgressView(value: focusedTab?.estimatedProgress ?? 0)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(focusedTab?.isLoading != true)
    }

    private var omniboxSecurityIcon: String {
        if focusedTab?.isPrivate == true { return "eye.slash.fill" }
        guard let url = focusedTab?.url else { return "magnifyingglass" }
        return url.scheme == "https" ? "lock.fill" : "globe"
    }

    private var omniboxSecurityColor: Color {
        if focusedTab?.isPrivate == true { return accentColor }
        return focusedTab?.url?.scheme == "https" ? LeafColors.secure : .secondary
    }

    private var reloadIsEnabled: Bool {
        focusedTab?.isLoading == true || focusedTab?.isExamProtected != true
    }

    private var reloadHelpText: String {
        if focusedTab?.isExamProtected == true { return "Reload disabled by Exam Protection" }
        return focusedTab?.isLoading == true ? "Stop loading" : "Reload"
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
        if focusedTab?.isLoading == true {
            focusedTab?.webView.stopLoading()
        } else if focusedTab?.isExamProtected != true {
            focusedTab?.webView.reload()
        }
    }

    private func toggleExamProtection() {
        guard let tab = focusedTab else { return }
        examProtection.protect(tab, enabled: !tab.isExamProtected)
    }

    private func toggleBookmark() {
        guard let tab = focusedTab else { return }
        libraryManager.toggleBookmark(title: tab.title, url: tab.url)
    }

    private func openDeveloperConsole() {
        focusedTab?.webView.isInspectable = settings.value.webInspector
        showDeveloperConsole = true
    }

    private func submitAddress() {
        guard focusedTab?.isExamProtected != true else { return }
        if !tabManager.navigate(tabID: window.focusedTabID, to: addressText) {
            focusedTab?.navigationError = .invalidAddress
        }
    }

    private func syncAddress() { addressText = focusedTab?.url?.absoluteString ?? "" }

    private func focusOmnibox(selectingAll: Bool) {
        omniboxFocused = true
        if selectingAll { omniboxSelectionRequest &+= 1 }
    }

    private func validateConnectivity() {
        guard !validatingNetwork else { return }
        validatingNetwork = true
        Task {
            _ = await networkMonitor.validateConnectivity()
            validatingNetwork = false
        }
    }

    private func retryNavigation(for tab: BrowserTab) {
        guard !validatingNetwork else { return }
        if networkMonitor.isConnected {
            tab.retryLastNavigation()
            return
        }
        validatingNetwork = true
        Task {
            let connected = await networkMonitor.validateConnectivity()
            if connected { tab.retryLastNavigation() }
            validatingNetwork = false
        }
    }

    private func find(backwards: Bool) {
        guard !findText.isEmpty, let webView = focusedTab?.webView else { findResult = ""; return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(findText, configuration: configuration) { result in
            findResult = result.matchFound ? "Found" : "0/0"
        }
    }

    private func changeZoom(by amount: Double) {
        guard let webView = focusedTab?.webView else { return }
        webView.pageZoom = min(max(webView.pageZoom + amount, 0.5), 3)
    }

    private func copyCurrentLink() {
        guard let value = focusedTab?.url?.absoluteString else { return }
        LeafClipboard.copy(value)
    }

    private func printCurrentPage() {
        guard let webView = focusedTab?.webView else { return }
        webView.printOperation(with: NSPrintInfo.shared).run()
    }

    private func selectWorkspace(_ id: UUID) {
        window.workspaceID = id
        workspaceManager.selectWorkspace(id: id)
    }

    private func activateWorkspace(_ id: UUID?) {
        guard let id else { return }
        window.workspaceID = id
        workspaceManager.selectWorkspace(id: id)
        let allTabIDs = tabManager.tabs.map(\.id)
        let existingTabIDs = window.tabIDs
        let validTabIDs = Set(existingTabIDs)
        workspaceManager.reconcileTabs(allTabIDs, assigningUnownedTo: id)
        guard let workspace = workspaceManager.workspaces.first(where: { $0.id == id }) else { return }

        if let selected = workspace.selectedTabID, validTabIDs.contains(selected) {
            tabManager.selectTab(id: selected, in: window.id)
        } else if let first = workspace.tabIDs.first(where: validTabIDs.contains) {
            tabManager.selectTab(id: first, in: window.id)
        } else {
            let tab = tabManager.createTab(in: window.id)
            workspaceManager.moveTab(tab.id, to: id)
        }
    }

    private func synchronizeWorkspaceTabs(_ ids: [UUID]) {
        workspaceManager.reconcileTabs(tabManager.tabs.map(\.id), assigningUnownedTo: window.workspaceID)
        guard let workspace = selectedWorkspace else { return }
        let validTabIDs = Set(ids)

        if let active = window.focusedTabID, workspace.tabIDs.contains(active) {
            workspaceManager.rememberSelection(active)
        } else if let selected = workspace.selectedTabID, validTabIDs.contains(selected) {
            tabManager.selectTab(id: selected, in: window.id)
        } else if let first = workspace.tabIDs.first(where: validTabIDs.contains) {
            tabManager.selectTab(id: first, in: window.id)
        } else {
            let tab = tabManager.createTab(in: window.id)
            workspaceManager.moveTab(tab.id, to: workspace.id)
        }
    }

    private func openLibraryURL(_ url: URL) {
        if focusedTab?.url == nil { focusedTab?.load(url) }
        else { tabManager.createTab(opening: url, in: window.id) }
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

    private var browserBackground: Color {
        switch settings.value.appearance {
        case .system: LeafColors.background
        case .light: .white
        case .dark: Color(nsColor: .windowBackgroundColor)
        case .graphiteDark: Color(red: 0.055, green: 0.058, blue: 0.064)
        }
    }

    private var toolbarHeight: CGFloat {
        let base: CGFloat
        switch settings.value.density {
        case .compact: base = 44
        case .comfortable: base = BrowserChromeMetrics.toolbarHeight
        case .spacious: base = 54
        }
        switch settings.value.toolbarStyle {
        case .minimal: return max(42, base - 2)
        case .unified: return base
        case .floating: return base + 4
        }
    }

    private var toolbarHorizontalPadding: CGFloat {
        switch settings.value.toolbarStyle {
        case .minimal: 8
        case .unified: 10
        case .floating: 15
        }
    }

    private var toolbarIconSize: CGFloat {
        switch settings.value.toolbarIconScale {
        case .small: 11.5
        case .regular: BrowserChromeMetrics.toolbarIconSize
        case .large: 15.5
        }
    }

    private var toolbarGroupColor: Color {
        switch settings.value.toolbarStyle {
        case .minimal: .clear
        case .unified: LeafColors.chromeSurface
        case .floating: accentColor.opacity(0.095)
        }
    }

    private var toolbarGroupCornerRadius: CGFloat {
        settings.value.toolbarStyle == .floating ? 14 : 9
    }

    @ViewBuilder private var toolbarBackground: some View {
        switch settings.value.toolbarStyle {
        case .minimal:
            ZStack {
                if !settings.value.reducedTransparency { Rectangle().fill(.ultraThinMaterial) }
                browserBackground.opacity(settings.value.reducedTransparency ? 1 : 0.72)
            }
        case .unified:
            ZStack {
                if !settings.value.reducedTransparency { Rectangle().fill(.ultraThinMaterial) }
                LinearGradient(
                    colors: [Color.primary.opacity(0.045), Color.primary.opacity(0.018)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .floating:
            ZStack {
                browserBackground
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(settings.value.reducedTransparency ? AnyShapeStyle(browserBackground) : AnyShapeStyle(.regularMaterial))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.16))
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
            }
        }
    }

    private var accentColor: Color {
        if settings.value.useCustomAccent {
            return settings.value.customAccent.color
        }
        if settings.value.useWorkspaceAccent,
           let workspaceAccent = selectedWorkspace?.accentName {
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
        guard let value = selectedWorkspace?.homePage,
              !value.isEmpty, let url = URLResolver().resolve(value) else {
            tabManager.createTab(in: window.id)
            return
        }
        focusedTab?.load(url)
    }

    private var focusedTab: BrowserTab? { tabManager.tab(id: window.focusedTabID) }

    private var selectedWorkspace: BrowserWorkspace? {
        workspaceManager.workspaces.first { $0.id == window.workspaceID }
    }

    private func presentLibraryPanel(_ panel: BrowserLibraryPanel) {
        guard activeLibraryPanel != panel else { return }
        activeLibraryPanel = panel
    }

    private func detachTab(_ tabID: UUID) {
        let sourceFrame = window.frame
        let pointer = NSEvent.mouseLocation
        let isLiveDrag = tabManager.draggedTabID == tabID
        let destination = tabManager.createWindow(moving: tabID, workspaceID: window.workspaceID)
        if isLiveDrag {
            destination.frame = detachedWindowFrame(sourceFrame: sourceFrame, pointer: pointer)
        }
        openWindow(id: "browser", value: destination.id)
    }

    private func detachedWindowFrame(sourceFrame: CGRect?, pointer: CGPoint) -> CGRect {
        let fallbackSize = CGSize(width: 1_100, height: 720)
        let sourceSize = sourceFrame?.size ?? fallbackSize
        let size = CGSize(width: max(sourceSize.width, 820), height: max(sourceSize.height, 540))
        let visibleFrame = NSScreen.screens.first(where: { $0.frame.contains(pointer) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(origin: .zero, size: size)

        var origin = CGPoint(
            x: pointer.x - min(180, size.width * 0.24),
            y: pointer.y - size.height + 30
        )
        origin.x = min(max(origin.x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - size.width))
        origin.y = min(max(origin.y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }

    private func newPrivateTab() {
        let tab = tabManager.createPrivateTab(in: window.id)
        if let workspaceID = window.workspaceID {
            workspaceManager.moveTab(tab.id, to: workspaceID)
        }
    }

    private func shortcut(_ action: BrowserShortcutAction) -> BrowserShortcut {
        settings.shortcut(for: action)
    }
}

private struct PasswordSavePrompt: View {
    @Environment(\.leafAccentColor) private var accentColor
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
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 10))
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
                    .foregroundStyle(accentColor)
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
                    .tint(accentColor)
            }
        }
        .padding(14)
        .frame(width: 390)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(offer.isUpdate ? "Update saved password" : "Save password")
    }
}

private struct PasswordAutofillAccountPicker: View {
    @Environment(\.leafAccentColor) private var accentColor
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
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 9))
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
                            .foregroundStyle(accentColor)
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
                            .foregroundStyle(accentColor)
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
                .allowsHitTesting(false)
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

private struct DeveloperConfiguration: Equatable {
    let developerMode: Bool
    let webInspector: Bool
    let captureConsoleLogs: Bool
}
