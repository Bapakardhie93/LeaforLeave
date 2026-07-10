import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let host = NSView()
        attach(webView, to: host)
        return host
    }

    func updateNSView(_ host: NSView, context: Context) {
        guard host.subviews.first !== webView else { return }
        host.subviews.forEach { $0.removeFromSuperview() }
        attach(webView, to: host)
    }

    private func attach(_ webView: WKWebView, to host: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
    }
}
