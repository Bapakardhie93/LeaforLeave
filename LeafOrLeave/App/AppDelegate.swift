import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var tabManager: TabManager?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.tabManager?.tabs.contains(where: \.isExamProtected) == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Protected exam tab is open"
        alert.informativeText = "Quitting may cause unsaved exam answers to be lost."
        alert.addButton(withTitle: "Keep Browser Open")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
