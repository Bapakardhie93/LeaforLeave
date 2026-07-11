import Foundation
import Observation
import WebKit
import AppKit

enum BrowserTabState: String, Codable { case active, background, sleeping, frozen, discarded }

@MainActor
@Observable
final class BrowserTab: NSObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let id: UUID
    let webView: WKWebView
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

    weak var manager: TabManager?
    private var observations: [NSKeyValueObservation] = []
    private var mediaTask: Task<Void, Never>?
    private var faviconTask: Task<Void, Never>?

    init(id: UUID = UUID(), webView: WKWebView, title: String = "New Tab", url: URL? = nil) {
        self.id = id
        self.webView = webView
        self.title = title
        self.url = url
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.configuration.userContentController.add(self, name: MediaScriptProvider.name)
        webView.configuration.userContentController.addUserScript(MediaScriptProvider.script)
        webView.configuration.userContentController.add(self, name: DownloadScriptProvider.name)
        webView.configuration.userContentController.addUserScript(DownloadScriptProvider.script)
        observeWebView()
    }

    func load(_ url: URL) { webView.load(URLRequest(url: url)) }

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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: DownloadScriptProvider.name)
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        mediaTask?.cancel()
        faviconTask?.cancel()
        isMediaPlaying = false
        isPictureInPicture = false
        mediaStatus = MediaTabStatus()
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in self?.syncOnMain() }
        ]
    }

    nonisolated private func syncOnMain() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            title = webView.title?.isEmpty == false ? webView.title! : (url == nil ? "New Tab" : "Loading…")
            url = webView.url
            isLoading = webView.isLoading
            estimatedProgress = webView.estimatedProgress
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
            manager?.tabDidChange(self)
            refreshPageMetadata()
        }
    }

    private func refreshPageMetadata() {
        faviconTask?.cancel()
        if let host = url?.host, let iconURL = URL(string: "https://\(host)/favicon.ico") {
            faviconTask = Task { [weak self] in
                if let (data, _) = try? await URLSession.shared.data(from: iconURL),
                   let image = NSImage(data: data) { self?.favicon = image }
            }
        }
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

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) { report(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) { report(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { navigationError = .processTerminated }

    private func report(_ error: Error) {
        let value = error as NSError
        guard value.code != NSURLErrorCancelled else { return }
        // WebKit intentionally interrupts the frame navigation when the
        // response is handed off to WKDownload. This is a successful download
        // transition, not a navigation failure that should be shown to users.
        if value.domain == WKError.errorDomain, value.code == 102 { return }
        navigationError = .navigationFailed(value.localizedDescription)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        return manager?.handlePopup(request: navigationAction.request, configuration: configuration)
    }

    func webViewDidClose(_ webView: WKWebView) { manager?.closeTab(id: id) }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let resource: String
        switch type {
        case .camera: resource = "camera"
        case .microphone: resource = "microphone"
        case .cameraAndMicrophone: resource = "camera and microphone"
        @unknown default: resource = "media devices"
        }
        let host = origin.host.isEmpty ? "This website" : origin.host
        let alert = NSAlert()
        alert.messageText = "Allow \(host) to use your \(resource)?"
        alert.informativeText = "Only allow access for websites you trust. macOS may also ask for system permission."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don’t Allow")
        decisionHandler(alert.runModal() == .alertFirstButtonReturn ? .grant : .deny)
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
        if message.name == DownloadScriptProvider.name,
           let address = value["url"] as? String,
           let downloadURL = URL(string: address),
           downloadURL.scheme == "https" || downloadURL.scheme == "http" {
            webView.load(URLRequest(url: downloadURL))
            return
        }
        guard message.name == MediaScriptProvider.name else { return }
        let playing = value["playing"] as? Bool ?? false, video = value["video"] as? Bool ?? false, pip = value["pip"] as? Bool ?? false
        isMediaPlaying = playing; isMediaMuted = value["muted"] as? Bool ?? false; hasVideo = video; isPictureInPicture = pip
        mediaStatus.playbackState = pip ? .pictureInPicture : (playing ? (video ? .playingVideo : .playingAudio) : (video ? .paused : .none))
        mediaStatus.isMuted = isMediaMuted; mediaStatus.duration = value["duration"] as? Double; mediaStatus.currentTime = value["current"] as? Double
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { manager?.downloadManager?.register(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { manager?.downloadManager?.register(download) }
}
