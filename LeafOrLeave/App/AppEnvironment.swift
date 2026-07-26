import Observation

@MainActor
@Observable
final class AppEnvironment {
    let tabManager: TabManager
    let networkMonitor: NetworkMonitor
    let examProtection: ExamProtectionManager
    let suspensionManager: TabSuspensionManager
    let workspaceManager: WorkspaceManager
    let downloadManager: DownloadManager
    let mediaCoordinator: MediaCoordinator
    let settings: SettingsStore
    let libraryManager: LibraryManager
    let passwordVault: PasswordVault

    init(browserConfiguration: BrowserConfiguration = .default) {
        let preferences = SettingsStore()
        settings = preferences
        LeafLogStore.shared.setCollectionEnabled(preferences.value.diagnosticsMetrics)
        let vault = PasswordVault()
        passwordVault = vault
        let tabs = TabManager(
            webViewFactory: WebViewFactory(configuration: browserConfiguration),
            sessionStore: SessionStore(),
            restoresPreviousSession: preferences.value.reopenSession
        )
        let library = LibraryManager(); libraryManager = library; tabs.libraryManager = library
        tabManager = tabs
        networkMonitor = NetworkMonitor()
        examProtection = ExamProtectionManager()
        suspensionManager = TabSuspensionManager(tabs: tabs)
        workspaceManager = WorkspaceManager()
        tabs.workspaceManager = workspaceManager
        for window in tabs.windows where window.workspaceID == nil {
            window.workspaceID = workspaceManager.selectedWorkspaceID
        }
        tabs.settings = preferences
        tabs.applyDeveloperSettings()
        tabs.passwordVault = vault
        let downloads = DownloadManager(asksForDestination: { [weak settings] in
            settings?.value.askDownloadDestination ?? false
        })
        downloadManager = downloads; tabs.downloadManager = downloads
        mediaCoordinator = MediaCoordinator(tabs: tabs)
        suspensionManager.apply(preferences.value)
        workspaceManager.assignUnownedTabs(tabs.tabs.map(\.id))
        AppDelegate.tabManager = tabs
        AppDelegate.configureTouchBar(workspaces: workspaceManager, tabs: tabs)
        LeafLog.info("Application services initialized", category: .app)
    }
}
