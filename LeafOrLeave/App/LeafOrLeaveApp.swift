import SwiftUI
import WebKit

@main
struct LeafOrLeaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment()


    var body: some Scene {
        WindowGroup {
            BrowserView(tabManager: environment.tabManager, networkMonitor: environment.networkMonitor,
                        examProtection: environment.examProtection, suspensionManager: environment.suspensionManager,
                        workspaceManager: environment.workspaceManager, downloadManager: environment.downloadManager,
                        mediaCoordinator: environment.mediaCoordinator, settings: environment.settings,
                        libraryManager: environment.libraryManager)
                .frame(minWidth: 820, minHeight: 540)
                .ignoresSafeArea(.container, edges: .top)
                .sheet(isPresented: Binding(get: { !environment.settings.value.onboardingCompleted }, set: { _ in })) { OnboardingView(settings: environment.settings) }
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") { environment.tabManager.createTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Reopen Closed Tab") { environment.tabManager.reopenLastClosedTab() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Button("Open File…") { environment.tabManager.openLocalFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Close Tab") { environment.tabManager.closeSelectedTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Tabs") {
                Button("Next Tab") { environment.tabManager.selectRelative(1) }
                    .keyboardShortcut(.tab, modifiers: .control)
                Button("Previous Tab") { environment.tabManager.selectRelative(-1) }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])
                ForEach(1...9, id: \.self) { number in
                    Button(number == 9 ? "Last Tab" : "Tab \(number)") { environment.tabManager.selectTab(number: number) }
                        .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
                }
                Divider()
                Button("Move Tab Left") {
                    if let id = environment.tabManager.selectedTabID { environment.tabManager.moveTab(id: id, by: -1) }
                }.keyboardShortcut("[", modifiers: [.command, .shift])
                Button("Move Tab Right") {
                    if let id = environment.tabManager.selectedTabID { environment.tabManager.moveTab(id: id, by: 1) }
                }.keyboardShortcut("]", modifiers: [.command, .shift])
            }
            CommandMenu("Browser") {
                Button(environment.settings.value.showSidebar ? "Hide Sidebar" : "Show Sidebar") { environment.settings.value.showSidebar.toggle() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Mute All Tabs") { environment.mediaCoordinator.muteAll() }
                Button("Zoom In") { if let view = environment.tabManager.selectedTab?.webView { view.pageZoom = min(view.pageZoom + 0.1, 3) } }.keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { if let view = environment.tabManager.selectedTab?.webView { view.pageZoom = max(view.pageZoom - 0.1, 0.5) } }.keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { environment.tabManager.selectedTab?.webView.pageZoom = 1 }.keyboardShortcut("0", modifiers: .command)
                Button("Hard Reload") { environment.tabManager.selectedTab?.webView.reloadFromOrigin() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Study Workspace") { if let id = environment.workspaceManager.workspaces.first?.id { environment.workspaceManager.selectWorkspace(id: id) } }.keyboardShortcut("1", modifiers: [.command, .shift])
                Button("Coding Workspace") { if environment.workspaceManager.workspaces.indices.contains(1) { environment.workspaceManager.selectWorkspace(id: environment.workspaceManager.workspaces[1].id) } }.keyboardShortcut("2", modifiers: [.command, .shift])
                Button("Media Workspace") { if environment.workspaceManager.workspaces.indices.contains(2) { environment.workspaceManager.selectWorkspace(id: environment.workspaceManager.workspaces[2].id) } }.keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }
        Settings { SettingsWindow(settings: environment.settings, tabs: environment.tabManager,
                                  downloads: environment.downloadManager, exams: environment.examProtection,
                                  workspaces: environment.workspaceManager, network: environment.networkMonitor,
                                  suspension: environment.suspensionManager,
                                  passwordVault: environment.passwordVault) }
    }
}
