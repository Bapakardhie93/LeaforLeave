import WebKit

@MainActor
struct WebViewFactory {
    private let configuration: BrowserConfiguration

    init(configuration: BrowserConfiguration) {
        self.configuration = configuration
    }

    func makeWebView() -> WKWebView {
        makeWebView(configuration: configuration.makeWebViewConfiguration())
    }

    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        // Keep WebKit's platform-correct Safari identity instead of impersonating Chromium.
        webView.customUserAgent = Self.safariUserAgent
        return webView
    }

    private static var safariUserAgent: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X \(version.majorVersion)_\(version.minorVersion)) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    }
}
