import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView
    var onFocus: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(onFocus: onFocus) }

    func makeNSView(context: Context) -> NSView {
        let host = NSView()
        host.wantsLayer = true
        host.layer?.masksToBounds = true
        attach(webView, to: host)
        context.coordinator.attach(to: webView)
        return host
    }

    func updateNSView(_ host: NSView, context: Context) {
        context.coordinator.onFocus = onFocus
        guard host.subviews.first !== webView else { return }
        host.subviews.forEach { $0.removeFromSuperview() }
        attach(webView, to: host)
        context.coordinator.attach(to: webView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    private func attach(_ webView: WKWebView, to host: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = host.bounds
        webView.autoresizingMask = [.width, .height]
        host.addSubview(webView)
    }

    final class Coordinator: NSObject {
        var onFocus: () -> Void
        private weak var attachedWebView: WKWebView?
        private var mouseMonitor: Any?

        init(onFocus: @escaping () -> Void) { self.onFocus = onFocus }

        func attach(to webView: WKWebView) {
            guard attachedWebView !== webView else { return }
            detach()
            attachedWebView = webView
            mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self, weak webView] event in
                guard let self, let webView,
                      event.window === webView.window,
                      webView.bounds.contains(webView.convert(event.locationInWindow, from: nil)) else {
                    return event
                }

                // Focus the split panel after WebKit has received this event.
                // Returning the original event is essential: links, controls,
                // selections, drag operations and context menus stay native.
                DispatchQueue.main.async { [weak self] in self?.onFocus() }
                return event
            }
        }

        func detach() {
            if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
            mouseMonitor = nil
            attachedWebView = nil
        }

        deinit {
            if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        }
    }
}
