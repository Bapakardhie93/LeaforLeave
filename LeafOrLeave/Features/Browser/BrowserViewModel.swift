import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class BrowserViewModel {
    let webView: WKWebView

    var addressText = ""
    private(set) var pageTitle = "LeafOrLeave"
    private(set) var currentURL: URL?
    private(set) var isLoading = false
    private(set) var estimatedProgress = 0.0
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var navigationError: BrowserNavigationError?

    private let urlResolver: URLResolver

    init(webViewFactory: WebViewFactory, urlResolver: URLResolver = URLResolver()) {
        webView = webViewFactory.makeWebView()
        self.urlResolver = urlResolver
        navigate(to: "https://www.google.com")
    }

    func navigateFromOmnibox() {
        navigate(to: addressText)
    }

    func navigate(to input: String) {
        guard let url = urlResolver.resolve(input) else {
            navigationError = .invalidAddress
            return
        }
        navigationError = nil
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        navigationError = nil
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func dismissError() {
        navigationError = nil
    }

    func synchronize(
        title: String?,
        url: URL?,
        isLoading: Bool,
        estimatedProgress: Double,
        canGoBack: Bool,
        canGoForward: Bool
    ) {
        if let title, !title.isEmpty { pageTitle = title }
        currentURL = url
        if let url { addressText = url.absoluteString }
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }

    func reportNavigationError(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        let failingURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url
        navigationError = .navigationFailure(from: nsError, failingURL: failingURL)
    }

    func reportWebProcessTermination() {
        isLoading = false
        navigationError = .processTerminated
    }
}
