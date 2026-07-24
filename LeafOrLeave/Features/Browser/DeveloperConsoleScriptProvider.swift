import WebKit

enum DeveloperConsoleScriptProvider {
    static let name = "leafDeveloperConsole"

    static let script = WKUserScript(source: """
    (() => {
      if (window.__leafDeveloperConsoleInstalled) return;
      window.__leafDeveloperConsoleInstalled = true;
      const send = (level, values) => {
        try {
          const message = values.map(value => {
            if (typeof value === 'string') return value;
            try { return JSON.stringify(value); } catch (_) { return String(value); }
          }).join(' ');
          window.webkit.messageHandlers.leafDeveloperConsole.postMessage({
            level, message, source: location.href, time: Date.now()
          });
        } catch (_) {}
      };
      ['log', 'info', 'warn', 'error', 'debug'].forEach(level => {
        const original = console[level];
        console[level] = function(...values) {
          send(level, values);
          return original.apply(console, values);
        };
      });
      window.addEventListener('error', event => send('error', [
        event.message + ' (' + event.filename + ':' + event.lineno + ':' + event.colno + ')'
      ]));
      window.addEventListener('unhandledrejection', event => send('error', [
        'Unhandled promise rejection:', event.reason
      ]));
    })();
    """, injectionTime: .atDocumentStart, forMainFrameOnly: false)
}
