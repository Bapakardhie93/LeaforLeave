import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTouchBarProvider {
    static weak var tabManager: TabManager?
    static var isTerminating = false
    private(set) static var workspaceTouchBarController: WorkspaceTouchBarController?

    var touchBar: NSTouchBar? { Self.workspaceTouchBarController?.touchBar }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        Self.installTouchBar()
        Task { @MainActor in Self.installTouchBar() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Self.installTouchBar()
    }

    static func configureTouchBar(workspaces: WorkspaceManager, tabs: TabManager) {
        workspaceTouchBarController = WorkspaceTouchBarController(
            workspaces: workspaces,
            tabs: tabs
        )
        installTouchBar()
    }

    private static func installTouchBar() {
        guard let touchBar = workspaceTouchBarController?.touchBar else { return }
        NSApplication.shared.touchBar = touchBar
        for window in NSApplication.shared.windows {
            window.touchBar = touchBar
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.tabManager?.tabs.contains(where: \.isExamProtected) == true else {
            Self.isTerminating = true
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "Protected exam tab is open"
        alert.informativeText = "Quitting may cause unsaved exam answers to be lost."
        alert.addButton(withTitle: "Keep Browser Open")
        alert.addButton(withTitle: "Quit Anyway")
        if alert.runModal() == .alertSecondButtonReturn {
            Self.isTerminating = true
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) { Self.isTerminating = true }
}
