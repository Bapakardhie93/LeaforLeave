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

    init(browserConfiguration: BrowserConfiguration = .default) {
        let tabs = TabManager(
            webViewFactory: WebViewFactory(configuration: browserConfiguration),
            sessionStore: SessionStore()
        )
        let library = LibraryManager(); libraryManager = library; tabs.libraryManager = library
        tabManager = tabs
        networkMonitor = NetworkMonitor()
        examProtection = ExamProtectionManager()
        suspensionManager = TabSuspensionManager(tabs: tabs)
        workspaceManager = WorkspaceManager()
        let downloads = DownloadManager(); downloadManager = downloads; tabs.downloadManager = downloads
        mediaCoordinator = MediaCoordinator(tabs: tabs)
        settings = SettingsStore()
        workspaceManager.assignUnownedTabs(tabs.tabs.map(\.id))
        AppDelegate.tabManager = tabs
    }
}
