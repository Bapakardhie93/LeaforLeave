import WebKit

enum NavigationStateScriptProvider {
    static let name = "leafNavigationState"

    static var script: WKUserScript {
        WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    static let source = #"""
    (() => {
      if (window.__leafNavigationStateInstalled) return;
      window.__leafNavigationStateInstalled = true;

      let pending = false;
      let entries = [location.href];
      let cursor = 0;
      const publish = () => {
        if (pending) return;
        pending = true;
        queueMicrotask(() => {
          pending = false;
          try {
            window.webkit.messageHandlers.leafNavigationState.postMessage({
              href: location.href,
              title: document.title || '',
              sameDocumentCanGoBack: cursor > 0,
              sameDocumentCanGoForward: cursor < entries.length - 1
            });
          } catch (_) {}
        });
      };

      for (const method of ['pushState', 'replaceState']) {
        const original = history[method];
        history[method] = function(...args) {
          const result = original.apply(this, args);
          if (method === 'pushState') {
            entries.splice(cursor + 1);
            entries.push(location.href);
            cursor = entries.length - 1;
          } else {
            entries[cursor] = location.href;
          }
          publish();
          return result;
        };
      }

      addEventListener('popstate', () => {
        const candidates = entries
          .map((href, index) => ({ href, index, distance: Math.abs(index - cursor) }))
          .filter(item => item.href === location.href)
          .sort((a, b) => a.distance - b.distance);
        if (candidates.length) cursor = candidates[0].index;
        else {
          entries.splice(cursor + 1);
          entries.push(location.href);
          cursor = entries.length - 1;
        }
        publish();
      }, { passive: true });
      for (const event of ['hashchange', 'pageshow']) addEventListener(event, publish, { passive: true });

      addEventListener('DOMContentLoaded', () => {
        const title = document.querySelector('title');
        if (title) new MutationObserver(publish).observe(title, { childList: true, subtree: true });
        publish();
      }, { once: true });
    })();
    """#
}
