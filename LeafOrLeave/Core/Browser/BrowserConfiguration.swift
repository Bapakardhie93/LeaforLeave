import WebKit

struct BrowserConfiguration: Sendable {
    let allowsJavaScript: Bool
    let allowsAirPlay: Bool
    let allowsMediaAutoplay: Bool
    let allowsPictureInPicture: Bool

    nonisolated static let `default` = BrowserConfiguration(
        allowsJavaScript: true,
        allowsAirPlay: true,
        allowsMediaAutoplay: true,
        allowsPictureInPicture: true
    )

    @MainActor
    func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = allowsJavaScript
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.allowsAirPlayForMediaPlayback = allowsAirPlay
        // WKWebView on macOS exposes HTML5 Picture in Picture through WebKit when
        // inline media and JavaScript are enabled; the explicit switch is iOS-only.
        configuration.mediaTypesRequiringUserActionForPlayback = allowsMediaAutoplay ? [] : .all
        return configuration
    }
}
