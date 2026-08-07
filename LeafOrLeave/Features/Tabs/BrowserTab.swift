import Foundation
import Observation
import WebKit
import AppKit
import AVFoundation

private enum WebViewObservation: Sendable {
    case title, url, loading, progress, backForward
}

enum BrowserTabState: String, Codable { case active, background, sleeping, frozen, discarded }

struct PasswordAutofillAccount: Identifiable, Equatable {
    let id: UUID
    let username: String
}

struct PasswordSaveOffer: Identifiable, Equatable {
    let id: UUID
    let host: String
    let username: String
    let isUpdate: Bool
}

private struct PendingPasswordSubmission {
    let id: UUID
    let host: String
    let username: String
    let password: String
    let documentID: String
    let submittedAt: Date
}

private struct ObservedPasswordPageState {
    let documentID: String
    let hasPassword: Bool
}

@MainActor
@Observable
final class BrowserTab: NSObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private static let faviconCache = NSCache<NSURL, NSImage>()

    let id: UUID
    let webView: WKWebView
    let isPrivate: Bool
    var title: String
    var url: URL?
    var isLoading = false
    var estimatedProgress = 0.0
    var canGoBack = false
    var canGoForward = false
    var isPinned = false
    var lifecycleState: BrowserTabState = .background
    var lastActiveAt = Date()
    var navigationError: BrowserNavigationError?
    var favicon: NSImage?
    var isMediaPlaying = false
    var isMediaMuted = false
    var hasVideo = false
    var isPictureInPicture = false
    var isExamProtected = false
    var isDownloading = false
    var isUploading = false
    var lifecycleSnapshot: WebViewLifecycleSnapshot?
    var mediaStatus = MediaTabStatus()
    var consoleMessages: [DeveloperConsoleMessage] = []
    var passwordAutofillAccounts: [PasswordAutofillAccount] = []
    var passwordAutofillHost: String?
    var passwordSaveOffer: PasswordSaveOffer?
    private(set) var lastFailedURL: URL?

    weak var manager: TabManager?
    private var observations: [NSKeyValueObservation] = []
    private var mediaTask: Task<Void, Never>?
    private var faviconTask: Task<Void, Never>?
    private var lastCredentialCapture: (host: String, username: String, passwordFingerprint: Int, date: Date)?
    private var autofillInProgress = false
    private var passwordAutofillDismissedForNavigation = false
    private var possibleUsername: (host: String, value: String, date: Date)?
    private var pendingPasswordSubmission: PendingPasswordSubmission?
    private var saveOfferCredential: PendingPasswordSubmission?
    private var latestPasswordPageState: ObservedPasswordPageState?
    private var passwordSubmissionConfirmationTask: Task<Void, Never>?
    private var pendingPasswordExpiryTask: Task<Void, Never>?
    private var passwordSaveOfferExpiryTask: Task<Void, Never>?
    private var faviconHost: String?
    private var sameDocumentCanGoBack = false
    private var sameDocumentCanGoForward = false

    init(id: UUID = UUID(), webView: WKWebView, title: String = "New Tab", url: URL? = nil,
         isPrivate: Bool = false) {
        self.id = id
        self.webView = webView
        self.isPrivate = isPrivate
        self.title = title
        self.url = url
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.configuration.userContentController.add(self, name: MediaScriptProvider.name)
        webView.configuration.userContentController.addUserScript(MediaScriptProvider.script)
        webView.configuration.userContentController.add(self, name: DeveloperConsoleScriptProvider.name)
        webView.configuration.userContentController.addUserScript(DeveloperConsoleScriptProvider.script)
        webView.configuration.userContentController.add(self, name: PasswordScriptProvider.name)
        webView.configuration.userContentController.addUserScript(PasswordScriptProvider.script)
        webView.configuration.userContentController.add(self, name: NavigationStateScriptProvider.name)
        webView.configuration.userContentController.addUserScript(NavigationStateScriptProvider.script)
        observeWebView()
    }

    func load(_ url: URL) {
        navigationError = nil
        lastFailedURL = nil
        webView.load(URLRequest(url: url))
    }

    func retryLastNavigation() {
        navigationError = nil
        if let lastFailedURL {
            self.lastFailedURL = nil
            webView.load(URLRequest(url: lastFailedURL))
        } else if webView.url != nil || url != nil {
            webView.reload()
        }
    }

    @discardableResult
    func navigateBack() -> Bool {
        if let item = webView.backForwardList.backItem {
            navigationError = nil
            webView.go(to: item)
            syncNavigationState(afterNavigation: true)
            return true
        }
        guard sameDocumentCanGoBack else {
            syncNavigationState()
            return false
        }
        webView.evaluateJavaScript("history.back()")
        return true
    }

    @discardableResult
    func navigateForward() -> Bool {
        if let item = webView.backForwardList.forwardItem {
            navigationError = nil
            webView.go(to: item)
            syncNavigationState(afterNavigation: true)
            return true
        }
        guard sameDocumentCanGoForward else {
            syncNavigationState()
            return false
        }
        webView.evaluateJavaScript("history.forward()")
        return true
    }

    func sleep() { guard lifecycleState == .background else { return }; lifecycleState = .sleeping }

    func freeze() {
        guard !isExamProtected else { return }
        Task { [weak self] in
            guard let self else { return }
            let y = (try? await webView.evaluateJavaScript("window.scrollY") as? Double) ?? 0
            lifecycleSnapshot = WebViewLifecycleSnapshot(url: url, title: title, scrollY: y)
            webView.stopLoading(); lifecycleState = .frozen
        }
    }

    func discard() {
        guard !isExamProtected else { return }
        Task { [weak self] in
            guard let self else { return }
            let y = (try? await webView.evaluateJavaScript("window.scrollY") as? Double) ?? 0
            lifecycleSnapshot = WebViewLifecycleSnapshot(url: url, title: title, scrollY: y)
            webView.loadHTMLString("", baseURL: nil); lifecycleState = .discarded
        }
    }

    func restoreIfNeeded() {
        guard lifecycleState == .discarded, let snapshot = lifecycleSnapshot, let url = snapshot.url else { lifecycleState = .active; return }
        load(url); lifecycleState = .active
    }

    func tearDown() {
        // Stopping a navigation does not stop media that is already playing.
        // Shut the page down before releasing the WKWebView so audio, video and
        // Picture in Picture cannot survive a closed tab.
        let stopMediaScript = """
        (() => {
          if (document.pictureInPictureElement && document.exitPictureInPicture) {
            document.exitPictureInPicture().catch(() => {});
          }
          document.querySelectorAll('audio, video').forEach(media => {
            media.pause();
            media.removeAttribute('src');
            media.querySelectorAll('source').forEach(source => source.removeAttribute('src'));
            media.load();
          });
          if (window.AudioContext) {
            // Web Audio contexts created by the page are released with the
            // document immediately below.
          }
        })()
        """
        webView.evaluateJavaScript(stopMediaScript)
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.removeFromSuperview()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: MediaScriptProvider.name)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: DeveloperConsoleScriptProvider.name)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: PasswordScriptProvider.name)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: NavigationStateScriptProvider.name)
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        mediaTask?.cancel()
        faviconTask?.cancel()
        passwordSubmissionConfirmationTask?.cancel()
        pendingPasswordExpiryTask?.cancel()
        passwordSaveOfferExpiryTask?.cancel()
        pendingPasswordSubmission = nil
        saveOfferCredential = nil
        passwordSaveOffer = nil
        possibleUsername = nil
        isMediaPlaying = false
        isPictureInPicture = false
        mediaStatus = MediaTabStatus()
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.title) },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.url) },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.loading) },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.progress) },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.backForward) },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain(.backForward) }
        ]
    }

    private func syncNavigationState(afterNavigation: Bool = false) {
        let currentURL = webView.url
        if url != currentURL {
            url = currentURL
            refreshFavicon()
            manager?.tabDidChange(self)
        }
        let currentTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextTitle = currentTitle.isEmpty ? (currentURL == nil ? "New Tab" : "Loading…") : currentTitle
        if title != nextTitle {
            title = nextTitle
            manager?.tabDidChange(self)
        }
        canGoBack = webView.backForwardList.backItem != nil || sameDocumentCanGoBack
        canGoForward = webView.backForwardList.forwardItem != nil || sameDocumentCanGoForward

        guard afterNavigation else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.syncNavigationState()
        }
    }

    nonisolated private func syncOnMain(_ observation: WebViewObservation) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch observation {
            case .title:
                let value = webView.title?.isEmpty == false
                    ? webView.title!
                    : (url == nil ? "New Tab" : "Loading…")
                guard value != title else { return }
                title = value
                manager?.tabDidChange(self)
            case .url:
                let value = webView.url
                guard value != url else { return }
                url = value
                manager?.tabDidChange(self)
                refreshFavicon()
            case .loading:
                let value = webView.isLoading
                guard value != isLoading else { return }
                isLoading = value
            case .progress:
                let value = webView.estimatedProgress
                guard value != estimatedProgress else { return }
                estimatedProgress = value
            case .backForward:
                let newCanGoBack = webView.canGoBack || sameDocumentCanGoBack
                let newCanGoForward = webView.canGoForward || sameDocumentCanGoForward
                if canGoBack != newCanGoBack { canGoBack = newCanGoBack }
                if canGoForward != newCanGoForward { canGoForward = newCanGoForward }
            }
        }
    }

    private func refreshFavicon() {
        faviconTask?.cancel()
        guard let host = url?.host,
              let iconURL = URL(string: "https://\(host)/favicon.ico") else {
            faviconHost = nil
            favicon = nil
            return
        }
        guard host != faviconHost || favicon == nil else { return }
        faviconHost = host
        favicon = nil
        if let cached = Self.faviconCache.object(forKey: iconURL as NSURL) {
            favicon = cached
            return
        }

        faviconTask = Task { [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: iconURL),
                  ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400,
                  let image = NSImage(data: data),
                  let self, faviconHost == host else { return }
            Self.faviconCache.setObject(image, forKey: iconURL as NSURL)
            favicon = image
        }
    }

    private func refreshMediaMetadata() {
        mediaTask?.cancel()
        mediaTask = Task { [weak self] in
            guard let self else { return }
            let script = """
            (() => { const m=[...document.querySelectorAll('audio,video')]; const v=m.filter(x=>x.tagName==='VIDEO'); return {playing:m.some(x=>!x.paused&&!x.ended), muted:m.some(x=>x.muted), video:v.length>0, pip:document.pictureInPictureElement!=null}; })()
            """
            if let value = try? await webView.evaluateJavaScript(script) as? [String: Bool] {
                isMediaPlaying = value["playing"] ?? false
                isMediaMuted = value["muted"] ?? false
                hasVideo = value["video"] ?? false
                isPictureInPicture = value["pip"] ?? false
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        syncNavigationState()
        report(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        syncNavigationState()
        report(error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        LeafLog.error("Web content process terminated", category: .browser)
        lastFailedURL = webView.url ?? url
        navigationError = .processTerminated
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        sameDocumentCanGoBack = false
        sameDocumentCanGoForward = false
        syncNavigationState(afterNavigation: true)
        passwordAutofillDismissedForNavigation = false
        passwordAutofillAccounts = []
        passwordAutofillHost = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
        navigationError = nil
        lastFailedURL = nil
        syncNavigationState(afterNavigation: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        syncNavigationState()
        let captureEnabled = manager?.settings?.value.offerToSavePasswords == true
        let consoleCaptureEnabled = manager?.settings?.value.developerMode == true
            && manager?.settings?.value.captureConsoleLogs == true
        webView.evaluateJavaScript("""
        window.__leafPasswordCaptureEnabled = \(captureEnabled ? "true" : "false");
        window.__leafDeveloperConsoleCaptureEnabled = \(consoleCaptureEnabled ? "true" : "false");
        window.__leafPasswordManagerRefresh?.();
        """)
        manager?.tabDidFinishNavigation(self)
        refreshFavicon()
        refreshMediaMetadata()
    }

    private func report(_ error: Error) {
        let value = error as NSError
        guard value.code != NSURLErrorCancelled else { return }
        // WebKit intentionally interrupts the frame navigation when the
        // response is handed off to WKDownload. This is a successful download
        // transition, not a navigation failure that should be shown to users.
        let webKitDomains = [WKError.errorDomain, "WebKitErrorDomain"]
        if webKitDomains.contains(value.domain),
           value.code == 102 { return } // WebKit's frame-load-interrupted-by-policy code.

        // Old session/history entries may still contain the HTTPS URL inferred
        // before LAN-aware address resolution was added. If that local HTTPS
        // endpoint refuses the connection, retry its HTTP endpoint once. The
        // fallback can never apply to public hosts or to an already-HTTP URL.
        let failedURL = (value.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
            ?? (value.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))
            ?? webView.url
            ?? url
        if value.domain == NSURLErrorDomain,
           [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut].contains(value.code),
           let failedURL,
           let fallbackURL = URLResolver().localHTTPFallback(for: failedURL) {
            LeafLog.notice("Retrying a local-network address over HTTP", category: .browser)
            navigationError = nil
            load(fallbackURL)
            return
        }
        LeafLog.warning(
            "Navigation failed (\(value.domain) \(value.code))",
            category: .browser
        )
        lastFailedURL = failedURL
        navigationError = .navigationFailure(from: value, failingURL: failedURL)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        return manager?.handlePopup(
            configuration: configuration,
            sourceTabID: id,
            isPrivate: isPrivate
        )
    }

    func webViewDidClose(_ webView: WKWebView) { manager?.closeTab(id: id) }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let response = navigationResponse.response
        let contentDisposition = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        let mimeType = response.mimeType?.lowercased() ?? ""
        let attachment = contentDisposition.contains("attachment")
        let downloadableMIMETypes: Set<String> = [
            "application/octet-stream", "application/x-apple-diskimage",
            "application/x-diskcopy", "application/zip", "application/x-zip-compressed",
            "application/x-7z-compressed", "application/x-rar-compressed"
        ]
        let shouldDownload = attachment || downloadableMIMETypes.contains(mimeType) || !navigationResponse.canShowMIMEType
        decisionHandler(shouldDownload ? .download : .allow)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let resource: String
        let mediaTypes: [AVMediaType]
        switch type {
        case .camera: resource = "camera"; mediaTypes = [.video]
        case .microphone: resource = "microphone"; mediaTypes = [.audio]
        case .cameraAndMicrophone: resource = "camera and microphone"; mediaTypes = [.video, .audio]
        @unknown default: resource = "media devices"; mediaTypes = []
        }
        let host = origin.host.isEmpty ? "This website" : origin.host
        let alert = NSAlert()
        alert.messageText = "Allow \(host) to use your \(resource)?"
        alert.informativeText = "Only allow access for websites you trust. macOS may also ask for system permission."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don’t Allow")
        guard alert.runModal() == .alertFirstButtonReturn else { decisionHandler(.deny); return }
        requestSystemMediaAccess(mediaTypes) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.prompt = "Choose"
        panel.message = parameters.allowsDirectories ? "Choose files or a folder to share with this website." : "Choose files to share with this website."
        panel.begin { response in completionHandler(response == .OK ? panel.urls : nil) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let value = message.body as? [String: Any] else { return }
        if message.name == NavigationStateScriptProvider.name {
            let oldURL = url
            if let href = value["href"] as? String, let currentURL = URL(string: href) {
                url = currentURL
            } else {
                url = webView.url
            }
            if let pageTitle = value["title"] as? String,
               !pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = pageTitle
            }
            sameDocumentCanGoBack = value["sameDocumentCanGoBack"] as? Bool ?? false
            sameDocumentCanGoForward = value["sameDocumentCanGoForward"] as? Bool ?? false
            canGoBack = webView.backForwardList.backItem != nil || sameDocumentCanGoBack
            canGoForward = webView.backForwardList.forwardItem != nil || sameDocumentCanGoForward
            manager?.tabDidChange(self)
            if oldURL != url { manager?.tabDidCommitSameDocumentNavigation(self) }
            return
        }
        if message.name == PasswordScriptProvider.name {
            guard !isPrivate else { return }
            let sourceHost = (value["host"] as? String).flatMap {
                $0.isEmpty ? nil : $0
            } ?? message.frameInfo.securityOrigin.host
            switch value["type"] as? String {
            case "fillableForm":
                let username = (value["username"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                rememberPossibleUsername(username, for: sourceHost)
                guard value["passwordKind"] as? String != "new" else { break }
                attemptPasswordAutofill(
                    usernameHint: username.isEmpty
                        ? recentPossibleUsername(for: sourceHost)
                        : username
                )
            case "submitted":
                stageCredentialSubmission(value, sourceHost: sourceHost)
            case "pageState":
                handlePasswordPageState(value)
            default:
                break
            }
            return
        }
        if message.name == DeveloperConsoleScriptProvider.name {
            guard manager?.settings?.value.developerMode == true,
                  manager?.settings?.value.captureConsoleLogs == true else { return }
            let item = DeveloperConsoleMessage(
                level: value["level"] as? String ?? "log",
                message: value["message"] as? String ?? "",
                source: value["source"] as? String ?? "",
                date: Date()
            )
            consoleMessages.append(item)
            if consoleMessages.count > 500 { consoleMessages.removeFirst(consoleMessages.count - 500) }
            return
        }
        guard message.name == MediaScriptProvider.name else { return }
        let playing = value["playing"] as? Bool ?? false, video = value["video"] as? Bool ?? false, pip = value["pip"] as? Bool ?? false
        isMediaPlaying = playing; isMediaMuted = value["muted"] as? Bool ?? false; hasVideo = video; isPictureInPicture = pip
        mediaStatus.playbackState = pip ? .pictureInPicture : (playing ? (video ? .playingVideo : .playingAudio) : (video ? .paused : .none))
        mediaStatus.isMuted = isMediaMuted; mediaStatus.duration = value["duration"] as? Double; mediaStatus.currentTime = value["current"] as? Double
    }

    private func rememberPossibleUsername(_ username: String, for host: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHost = PasswordCredential.normalized(host)
        guard !trimmed.isEmpty, !normalizedHost.isEmpty else { return }
        possibleUsername = (normalizedHost, trimmed, Date())
    }

    private func recentPossibleUsername(for host: String) -> String? {
        guard let possibleUsername,
              possibleUsername.host == PasswordCredential.normalized(host),
              Date().timeIntervalSince(possibleUsername.date) < 300 else {
            return nil
        }
        return possibleUsername.value
    }

    private func attemptPasswordAutofill(usernameHint: String? = nil) {
        guard manager?.settings?.value.autoFillPasswords == true,
              let host = webView.url?.host,
              let vault = manager?.passwordVault,
              vault.hasStoredCredential(for: host),
              !autofillInProgress else { return }
        autofillInProgress = true

        Task { [weak self] in
            guard let self else { return }
            defer { autofillInProgress = false }
            let minutes = manager?.settings?.value.passwordAutoLockMinutes ?? 5
            guard await vault.unlock(
                reason: "Fill your saved password for \(host) in LeafOrLeave.",
                autoLockMinutes: minutes
            ) else { return }

            let candidates = vault.credentials(for: host)
            guard !candidates.isEmpty else { return }
            let hint = usernameHint?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let credential: PasswordCredential?
            if !hint.isEmpty {
                credential = candidates.first {
                    $0.username.compare(hint, options: .caseInsensitive) == .orderedSame
                }
            } else if candidates.count == 1 {
                credential = candidates[0]
            } else {
                credential = nil
            }

            guard let credential else {
                presentPasswordAutofillAccounts(
                    candidates,
                    matching: hint,
                    host: host
                )
                return
            }

            passwordAutofillDismissedForNavigation = true
            passwordAutofillAccounts = []
            passwordAutofillHost = nil
            await fill(credential)
        }
    }

    private func presentPasswordAutofillAccounts(
        _ credentials: [PasswordCredential],
        matching hint: String,
        host: String
    ) {
        guard credentials.count > 1,
              !passwordAutofillDismissedForNavigation else { return }
        let matching = hint.isEmpty
            ? credentials
            : credentials.filter {
                $0.username.localizedCaseInsensitiveContains(hint)
            }
        passwordAutofillAccounts = (matching.isEmpty ? credentials : matching).map {
            PasswordAutofillAccount(id: $0.id, username: $0.username)
        }
        passwordAutofillHost = host
    }

    func dismissPasswordAutofillAccounts() {
        passwordAutofillDismissedForNavigation = true
        passwordAutofillAccounts = []
        passwordAutofillHost = nil
    }

    func selectPasswordAutofillAccount(id: UUID) {
        guard manager?.settings?.value.autoFillPasswords == true,
              let host = passwordAutofillHost,
              let vault = manager?.passwordVault,
              !autofillInProgress else { return }
        if let selectedAccount = passwordAutofillAccounts.first(where: { $0.id == id }) {
            rememberPossibleUsername(selectedAccount.username, for: host)
        }
        passwordAutofillDismissedForNavigation = true
        passwordAutofillAccounts = []
        passwordAutofillHost = nil
        autofillInProgress = true

        Task { [weak self] in
            guard let self else { return }
            defer { autofillInProgress = false }
            let minutes = manager?.settings?.value.passwordAutoLockMinutes ?? 5
            guard await vault.unlock(
                reason: "Fill your saved password for \(host) in LeafOrLeave.",
                autoLockMinutes: minutes
            ), let credential = vault.credentials(for: host).first(where: { $0.id == id }) else {
                return
            }
            await fill(credential, replacingExistingValues: true)
        }
    }

    private func fill(
        _ credential: PasswordCredential,
        replacingExistingValues: Bool = false
    ) async {
        rememberPossibleUsername(credential.username, for: credential.host)
        guard let script = PasswordScriptProvider.autofillScript(
            username: credential.username,
            password: credential.password,
            replacingExistingValues: replacingExistingValues
        ) else { return }
        _ = try? await webView.evaluateJavaScript(script)
    }

    private func stageCredentialSubmission(_ value: [String: Any], sourceHost: String) {
        guard manager?.settings?.value.offerToSavePasswords == true,
              let password = value["password"] as? String,
              !sourceHost.isEmpty, !password.isEmpty,
              let vault = manager?.passwordVault else { return }
        let host = PasswordCredential.normalized(sourceHost)
        let submittedUsername = (value["username"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedUsername = submittedUsername.isEmpty
            ? recentPossibleUsername(for: host) ?? ""
            : submittedUsername
        guard !host.isEmpty, !trimmedUsername.isEmpty else { return }
        rememberPossibleUsername(trimmedUsername, for: host)

        if vault.credentials(for: host).contains(where: {
            $0.username == trimmedUsername && $0.password == password
        }) {
            pendingPasswordSubmission = nil
            return
        }

        let passwordFingerprint = password.hashValue
        if let previous = lastCredentialCapture,
           previous.host == host,
           previous.username == trimmedUsername,
           previous.passwordFingerprint == passwordFingerprint,
           Date().timeIntervalSince(previous.date) < 10 { return }
        lastCredentialCapture = (host, trimmedUsername, passwordFingerprint, Date())

        passwordSubmissionConfirmationTask?.cancel()
        dismissPasswordSaveOffer()
        pendingPasswordSubmission = PendingPasswordSubmission(
            id: UUID(),
            host: host,
            username: trimmedUsername,
            password: password,
            documentID: value["documentID"] as? String ?? "",
            submittedAt: Date()
        )
        LeafLog.debug("Password submission held for success confirmation", category: .passwords)
        let pendingID = pendingPasswordSubmission?.id
        pendingPasswordExpiryTask?.cancel()
        pendingPasswordExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled,
                  self?.pendingPasswordSubmission?.id == pendingID else { return }
            self?.pendingPasswordSubmission = nil
        }
    }

    private func handlePasswordPageState(_ value: [String: Any]) {
        let documentID = value["documentID"] as? String ?? ""
        let hasPassword = value["hasPassword"] as? Bool ?? false
        latestPasswordPageState = ObservedPasswordPageState(
            documentID: documentID,
            hasPassword: hasPassword
        )

        if hasPassword {
            passwordSubmissionConfirmationTask?.cancel()
            return
        }

        guard let pending = pendingPasswordSubmission else { return }
        guard Date().timeIntervalSince(pending.submittedAt) < 180 else {
            pendingPasswordSubmission = nil
            return
        }

        let reason = value["reason"] as? String ?? ""
        let movedToAnotherDocument = !documentID.isEmpty &&
            documentID != pending.documentID
        let submittedFormDisappeared = ["mutation", "history", "delayed"]
            .contains(reason)
        guard movedToAnotherDocument || submittedFormDisappeared else { return }

        passwordSubmissionConfirmationTask?.cancel()
        let delay = movedToAnotherDocument ? 0.35 : 1.1
        passwordSubmissionConfirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self,
                  pendingPasswordSubmission?.id == pending.id,
                  latestPasswordPageState?.hasPassword == false else { return }
            presentPasswordSaveOffer(for: pending)
        }
    }

    private func presentPasswordSaveOffer(for pending: PendingPasswordSubmission) {
        guard manager?.settings?.value.offerToSavePasswords == true,
              let vault = manager?.passwordVault else {
            pendingPasswordSubmission = nil
            return
        }
        pendingPasswordExpiryTask?.cancel()
        pendingPasswordExpiryTask = nil
        pendingPasswordSubmission = nil
        saveOfferCredential = pending
        let isUpdate = vault.credentials(for: pending.host).contains {
            $0.username.compare(
                pending.username,
                options: .caseInsensitive
            ) == .orderedSame
        }
        passwordSaveOffer = PasswordSaveOffer(
            id: pending.id,
            host: pending.host,
            username: pending.username,
            isUpdate: isUpdate
        )
        LeafLog.notice(
            isUpdate ? "Password update offer presented" : "Password save offer presented",
            category: .passwords
        )
        passwordSaveOfferExpiryTask?.cancel()
        passwordSaveOfferExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled else { return }
            self?.dismissPasswordSaveOffer()
        }
    }

    func acceptPasswordSaveOffer() {
        guard let pending = saveOfferCredential,
              let vault = manager?.passwordVault else {
            dismissPasswordSaveOffer()
            return
        }
        passwordSaveOfferExpiryTask?.cancel()
        passwordSaveOffer = nil
        saveOfferCredential = nil

        Task {
            let minutes = manager?.settings?.value.passwordAutoLockMinutes ?? 5
            guard await vault.unlock(
                reason: "Save a password securely for \(pending.host).",
                autoLockMinutes: minutes
            ) else { return }
            do {
                try vault.save(
                    host: pending.host,
                    username: pending.username,
                    password: pending.password
                )
                LeafLog.notice("Credential saved to macOS Keychain", category: .passwords)
            } catch {
                let value = error as NSError
                LeafLog.error(
                    "Keychain save failed (\(value.domain) \(value.code))",
                    category: .passwords
                )
                let errorAlert = NSAlert(error: error)
                errorAlert.runModal()
            }
        }
    }

    func dismissPasswordSaveOffer() {
        passwordSaveOfferExpiryTask?.cancel()
        passwordSaveOfferExpiryTask = nil
        passwordSaveOffer = nil
        saveOfferCredential = nil
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { manager?.downloadManager?.register(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { manager?.downloadManager?.register(download) }

    private func requestSystemMediaAccess(_ mediaTypes: [AVMediaType], completion: @escaping (Bool) -> Void) {
        guard let mediaType = mediaTypes.first else { completion(true); return }
        let remaining = Array(mediaTypes.dropFirst())
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            requestSystemMediaAccess(remaining, completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { [weak tab = self] granted in
                Task { @MainActor [weak tab] in
                    guard let tab, granted else { completion(false); return }
                    tab.requestSystemMediaAccess(remaining, completion: completion)
                }
            }
        case .denied, .restricted:
            let alert = NSAlert()
            alert.messageText = "Media access is blocked by macOS"
            alert.informativeText = "Enable LeafOrLeave in System Settings → Privacy & Security, then reload this page."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(mediaType == .video ? "Camera" : "Microphone")") {
                NSWorkspace.shared.open(url)
            }
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
