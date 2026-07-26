import SwiftUI
import WebKit

@main
struct LeafOrLeaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment: AppEnvironment

    init() {
        _environment = State(initialValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup(id: "browser", for: UUID.self) { $windowID in
            if let window = environment.tabManager.window(id: windowID) {
                BrowserWindowSceneRoot(environment: environment, window: window)
            } else {
                ContentUnavailableView("Window unavailable", systemImage: "rectangle.badge.xmark")
            }
        } defaultValue: {
            environment.tabManager.initialWindowID
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            BrowserCommands(environment: environment)
        }

        Settings {
            SettingsWindow(settings: environment.settings, tabs: environment.tabManager,
                           downloads: environment.downloadManager, exams: environment.examProtection,
                           workspaces: environment.workspaceManager, network: environment.networkMonitor,
                           suspension: environment.suspensionManager,
                           passwordVault: environment.passwordVault)
        }
    }
}

private struct BrowserCommands: Commands {
    let environment: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                let window = environment.tabManager.createWindow(
                    workspaceID: environment.workspaceManager.selectedWorkspaceID
                )
                openWindow(id: "browser", value: window.id)
            }
            .keyboardShortcut(shortcut(.newWindow).keyEquivalent,
                              modifiers: shortcut(.newWindow).modifiers.eventModifiers)

            Button("New Tab") { environment.tabManager.createTab() }
                .keyboardShortcut(shortcut(.newTab).keyEquivalent,
                                  modifiers: shortcut(.newTab).modifiers.eventModifiers)
            Button("New Private Tab") { environment.tabManager.createPrivateTab() }
                .keyboardShortcut(shortcut(.newPrivateTab).keyEquivalent,
                                  modifiers: shortcut(.newPrivateTab).modifiers.eventModifiers)
            Button("Reopen Closed Tab") { environment.tabManager.reopenLastClosedTab() }
                .keyboardShortcut(shortcut(.reopenClosedTab).keyEquivalent,
                                  modifiers: shortcut(.reopenClosedTab).modifiers.eventModifiers)
        }

        CommandGroup(after: .saveItem) {
            Button("Open File…") { environment.tabManager.openLocalFile() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Close Tab") { environment.tabManager.closeSelectedTab() }
                .keyboardShortcut(shortcut(.closeTab).keyEquivalent,
                                  modifiers: shortcut(.closeTab).modifiers.eventModifiers)
            Button("Close Window") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandMenu("Tabs") {
            Button("Next Tab") { environment.tabManager.selectRelative(1) }
                .keyboardShortcut(.tab, modifiers: .control)
            Button("Previous Tab") { environment.tabManager.selectRelative(-1) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
            ForEach(1...9, id: \.self) { number in
                Button(number == 9 ? "Last Tab" : "Tab \(number)") {
                    environment.tabManager.selectTab(number: number)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
            }
            Divider()
            Button("Move Tab Left") {
                if let id = environment.tabManager.selectedTabID {
                    environment.tabManager.moveTab(id: id, by: -1)
                }
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            Button("Move Tab Right") {
                if let id = environment.tabManager.selectedTabID {
                    environment.tabManager.moveTab(id: id, by: 1)
                }
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            Divider()
            Button("Move Tab to New Window") {
                guard let tabID = environment.tabManager.selectedTabID else { return }
                let window = environment.tabManager.createWindow(
                    moving: tabID,
                    workspaceID: environment.workspaceManager.selectedWorkspaceID
                )
                openWindow(id: "browser", value: window.id)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandMenu("Layout") {
            Button("Add Split Panel") {
                guard let window = environment.tabManager.activeWindow, window.canAddSplit else { return }
                let available = environment.tabManager.tabs(in: window.id)
                    .first { !window.visibleTabIDs.contains($0.id) }
                let tab = available ?? environment.tabManager.createTab(activate: false, in: window.id)
                environment.tabManager.addToSplit(tabID: tab.id, in: window.id)
            }
            .keyboardShortcut(shortcut(.addSplit).keyEquivalent,
                              modifiers: shortcut(.addSplit).modifiers.eventModifiers)

            Button("Exit Split Screen") {
                guard let windowID = environment.tabManager.activeWindowID else { return }
                environment.tabManager.exitSplit(in: windowID)
            }
            .disabled(environment.tabManager.activeWindow?.isSplit != true)

            Divider()
            Button(environment.settings.value.showSidebar ? "Hide Sidebar" : "Show Sidebar") {
                environment.settings.value.showSidebar.toggle()
            }
            .keyboardShortcut(shortcut(.toggleSidebar).keyEquivalent,
                              modifiers: shortcut(.toggleSidebar).modifiers.eventModifiers)
        }

        CommandMenu("Browser") {
            Button("Back") { environment.tabManager.selectedTab?.navigateBack() }
                .keyboardShortcut(shortcut(.back).keyEquivalent,
                                  modifiers: shortcut(.back).modifiers.eventModifiers)
                .disabled(environment.tabManager.selectedTab?.canGoBack != true)
            Button("Forward") { environment.tabManager.selectedTab?.navigateForward() }
                .keyboardShortcut(shortcut(.forward).keyEquivalent,
                                  modifiers: shortcut(.forward).modifiers.eventModifiers)
                .disabled(environment.tabManager.selectedTab?.canGoForward != true)
            Button("Reload") { environment.tabManager.selectedTab?.webView.reload() }
                .keyboardShortcut(shortcut(.reload).keyEquivalent,
                                  modifiers: shortcut(.reload).modifiers.eventModifiers)
            Divider()
            Button("Mute All Tabs") { environment.mediaCoordinator.muteAll() }
            Button("Zoom In") {
                if let view = environment.tabManager.selectedTab?.webView {
                    view.pageZoom = min(view.pageZoom + 0.1, 3)
                }
            }
            .keyboardShortcut("+", modifiers: .command)
            Button("Zoom Out") {
                if let view = environment.tabManager.selectedTab?.webView {
                    view.pageZoom = max(view.pageZoom - 0.1, 0.5)
                }
            }
            .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { environment.tabManager.selectedTab?.webView.pageZoom = 1 }
                .keyboardShortcut("0", modifiers: .command)
            Button("Hard Reload") { environment.tabManager.selectedTab?.webView.reloadFromOrigin() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Study Workspace") { selectWorkspace(at: 0) }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Coding Workspace") { selectWorkspace(at: 1) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Media Workspace") { selectWorkspace(at: 2) }
                .keyboardShortcut("3", modifiers: [.command, .shift])
        }
    }

    private func shortcut(_ action: BrowserShortcutAction) -> BrowserShortcut {
        environment.settings.shortcut(for: action)
    }

    private func selectWorkspace(at index: Int) {
        guard environment.workspaceManager.workspaces.indices.contains(index),
              let window = environment.tabManager.activeWindow else { return }
        let id = environment.workspaceManager.workspaces[index].id
        window.workspaceID = id
        environment.workspaceManager.selectWorkspace(id: id)
    }
}
