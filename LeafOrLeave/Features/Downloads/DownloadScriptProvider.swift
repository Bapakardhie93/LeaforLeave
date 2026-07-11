import WebKit

enum DownloadScriptProvider {
    static let name = "leafDownload"
    static var script: WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    private static let source = """
    (() => {
      if (window.__leafDownloadBridge) return;
      window.__leafDownloadBridge = true;
      document.addEventListener('click', event => {
        const anchor = event.target instanceof Element ? event.target.closest('a[download]') : null;
        if (!anchor) return;
        const href = new URL(anchor.href, document.baseURI).href;
        if (!/^https?:/i.test(href)) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        window.webkit.messageHandlers.leafDownload.postMessage({ url: href });
      }, true);
    })();
    """
}
