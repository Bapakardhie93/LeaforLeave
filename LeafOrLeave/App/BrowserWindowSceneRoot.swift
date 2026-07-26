import AppKit
import SwiftUI

struct BrowserWindowSceneRoot: View {
    let environment: AppEnvironment
    let window: BrowserWindowState
    @Environment(\.openWindow) private var openWindow
    @State private var nativeWindow: NSWindow?

    var body: some View {
        BrowserView(
            tabManager: environment.tabManager,
            window: window,
            networkMonitor: environment.networkMonitor,
            examProtection: environment.examProtection,
            suspensionManager: environment.suspensionManager,
            workspaceManager: environment.workspaceManager,
            downloadManager: environment.downloadManager,
            mediaCoordinator: environment.mediaCoordinator,
            settings: environment.settings,
            libraryManager: environment.libraryManager
        )
        .frame(minWidth: 820, minHeight: 540)
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: onboardingPresented) {
            OnboardingView(settings: environment.settings)
        }
        .background {
            BrowserWindowBridge(
                windowID: window.id,
                restoredFrame: window.frame,
                becameKey: {
                    environment.tabManager.activateWindow(id: window.id)
                    if let workspaceID = window.workspaceID {
                        environment.workspaceManager.selectWorkspace(id: workspaceID)
                    }
                },
                frameChanged: { environment.tabManager.updateWindowFrame(id: window.id, frame: $0) },
                shouldClose: { confirmClosingProtectedTabs() },
                willClose: {
                    guard !AppDelegate.isTerminating else { return }
                    environment.tabManager.closeWindow(id: window.id)
                },
                resolved: { nativeWindow = $0 }
            )
        }
        .onAppear {
            environment.tabManager.activateWindow(id: window.id)
            for restoredID in environment.tabManager.restoredWindowIDs(excluding: window.id) {
                openWindow(id: "browser", value: restoredID)
            }
        }
        .onChange(of: window.tabIDs) { _, tabIDs in
            guard tabIDs.isEmpty else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                guard window.tabIDs.isEmpty else { return }
                nativeWindow?.performClose(nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .leafBrowserWindowShouldClose)) { notification in
            guard notification.object as? String == window.id.uuidString else { return }
            Task { @MainActor in
                await Task.yield()
                guard window.tabIDs.isEmpty else { return }
                nativeWindow?.performClose(nil)
            }
        }
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { !environment.settings.value.onboardingCompleted },
            set: { _ in }
        )
    }

    private func confirmClosingProtectedTabs() -> Bool {
        let protectedCount = environment.tabManager.tabs(in: window.id).filter(\.isExamProtected).count
        guard protectedCount > 0 else { return true }
        let alert = NSAlert()
        alert.messageText = protectedCount == 1
            ? "Protected exam tab is open"
            : "\(protectedCount) protected exam tabs are open"
        alert.informativeText = "Closing this window may cause unsaved exam answers to be lost."
        alert.addButton(withTitle: "Keep Window Open")
        alert.addButton(withTitle: "Close Anyway")
        return alert.runModal() == .alertSecondButtonReturn
    }
}

private struct BrowserWindowBridge: NSViewRepresentable {
    let windowID: UUID
    let restoredFrame: CGRect?
    let becameKey: () -> Void
    let frameChanged: (CGRect) -> Void
    let shouldClose: () -> Bool
    let willClose: () -> Void
    let resolved: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(restoredFrame: restoredFrame, becameKey: becameKey,
                    frameChanged: frameChanged, shouldClose: shouldClose,
                    willClose: willClose, resolved: resolved)
    }

    func makeNSView(context: Context) -> WindowResolvingView {
        let view = WindowResolvingView()
        view.onWindowChanged = { context.coordinator.bind(to: $0) }
        return view
    }

    func updateNSView(_ nsView: WindowResolvingView, context: Context) {
        context.coordinator.becameKey = becameKey
        context.coordinator.frameChanged = frameChanged
        context.coordinator.shouldClose = shouldClose
        context.coordinator.willClose = willClose
        if let window = nsView.window { context.coordinator.bind(to: window) }
    }

    static func dismantleNSView(_ nsView: WindowResolvingView, coordinator: Coordinator) {
        coordinator.unbind()
    }

    final class Coordinator {
        var becameKey: () -> Void
        var frameChanged: (CGRect) -> Void
        var shouldClose: () -> Bool
        var willClose: () -> Void
        private let restoredFrame: CGRect?
        private let resolved: (NSWindow) -> Void
        private weak var window: NSWindow?
        private var delegateProxy: WindowDelegateProxy?
        private var observers: [NSObjectProtocol] = []
        private var restored = false

        init(restoredFrame: CGRect?, becameKey: @escaping () -> Void,
             frameChanged: @escaping (CGRect) -> Void, shouldClose: @escaping () -> Bool,
             willClose: @escaping () -> Void,
             resolved: @escaping (NSWindow) -> Void) {
            self.restoredFrame = restoredFrame
            self.becameKey = becameKey
            self.frameChanged = frameChanged
            self.shouldClose = shouldClose
            self.willClose = willClose
            self.resolved = resolved
        }

        func bind(to newWindow: NSWindow?) {
            guard let newWindow, window !== newWindow else { return }
            unbind()
            window = newWindow
            resolved(newWindow)
            newWindow.tabbingMode = .disallowed
            let proxy = WindowDelegateProxy(original: newWindow.delegate) { [weak self] in
                self?.shouldClose() ?? true
            }
            delegateProxy = proxy
            newWindow.delegate = proxy
            if !restored, let restoredFrame, isVisibleOnAnyScreen(restoredFrame) {
                newWindow.setFrame(restoredFrame, display: false)
                restored = true
            }
            frameChanged(newWindow.frame)
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: newWindow, queue: .main) { [weak self] _ in
                    self?.becameKey()
                },
                center.addObserver(forName: NSWindow.didMoveNotification, object: newWindow, queue: .main) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.frameChanged(window.frame)
                },
                center.addObserver(forName: NSWindow.didResizeNotification, object: newWindow, queue: .main) { [weak self] _ in
                    guard let self, let window = self.window else { return }
                    self.frameChanged(window.frame)
                },
                center.addObserver(forName: NSWindow.willCloseNotification, object: newWindow, queue: .main) { [weak self] _ in
                    self?.willClose()
                }
            ]
        }

        func unbind() {
            if let window, window.delegate === delegateProxy {
                window.delegate = delegateProxy?.original
            }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            delegateProxy = nil
            window = nil
        }

        private func isVisibleOnAnyScreen(_ frame: CGRect) -> Bool {
            NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        }
    }
}

private final class WindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var original: NSWindowDelegate?
    private let canClose: () -> Bool

    init(original: NSWindowDelegate?, canClose: @escaping () -> Bool) {
        self.original = original
        self.canClose = canClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard canClose() else { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || original?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if original?.responds(to: selector) == true { return original }
        return super.forwardingTarget(for: selector)
    }
}

private final class WindowResolvingView: NSView {
    var onWindowChanged: (NSWindow?) -> Void = { _ in }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChanged(window)
    }
}
