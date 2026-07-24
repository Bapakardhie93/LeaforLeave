import Foundation
import Observation
import WebKit
import AppKit

@MainActor @Observable
final class MediaCoordinator {
    weak var tabs: TabManager?
    var autoPictureInPicture = false
    var pictureInPictureMessage: String?
    private var floatingPlayer: FloatingPiPController?
    var mediaTabs: [BrowserTab] { tabs?.tabs.filter { $0.mediaStatus.playbackState != .none } ?? [] }
    init(tabs: TabManager) { self.tabs = tabs }
    func togglePlayback(_ tab: BrowserTab) { tab.webView.evaluateJavaScript("(()=>{const m=document.querySelector('video,audio');if(!m)return false;m.paused?m.play():m.pause();return true})()") }
    func toggleMute(_ tab: BrowserTab) { tab.webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('video,audio')];const v=!a.every(x=>x.muted);a.forEach(x=>x.muted=v);return v})()") }
    func togglePiP(_ tab: BrowserTab) {
        let script = """
          try {
            const videos = [...document.querySelectorAll('video')].filter(v => v.readyState > 0);
            const video = videos.sort((a,b) => (b.clientWidth*b.clientHeight)-(a.clientWidth*a.clientHeight))[0];
            if (!video) return {ok:false, message:'No playable video was found on this page.'};
            if (document.pictureInPictureElement) {
              await document.exitPictureInPicture();
              return {ok:true, message:'Picture in Picture closed.'};
            }
            if (video.webkitPresentationMode === 'picture-in-picture' && video.webkitSetPresentationMode) {
              video.webkitSetPresentationMode('inline');
              return {ok:true, message:'Picture in Picture closed.'};
            }
            if (video.webkitSetPresentationMode) {
              try {
                if (video.paused) await video.play();
                video.webkitSetPresentationMode('picture-in-picture');
                if (video.webkitPresentationMode === 'picture-in-picture') {
                  return {ok:true, message:'Picture in Picture started with WebKit.'};
                }
              } catch (_) {}
            }
            if (video.requestPictureInPicture && document.pictureInPictureEnabled !== false) {
              try {
                if (video.paused) await video.play();
                await video.requestPictureInPicture();
                return {ok:true, message:'Picture in Picture started.'};
              } catch (standardError) {
                return {ok:false, message:standardError.name + ': ' + standardError.message};
              }
            }
            return {ok:false, message:'This website or video does not allow Picture in Picture.'};
          } catch (error) {
            return {ok:false, message:error.name + ': ' + error.message};
          }
        """
        Task { @MainActor [weak self, weak tab] in
            guard let self, let tab else { return }
            do {
                let value = try await tab.webView.callAsyncJavaScript(
                    script,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                let response = value as? [String: Any]
                self.pictureInPictureMessage = response?["message"] as? String ?? "Picture in Picture could not be started."
                if response?["ok"] as? Bool == true {
                    tab.isPictureInPicture = self.pictureInPictureMessage?.contains("started") == true
                } else {
                    self.openFloatingPlayer(for: tab)
                }
            } catch {
                self.pictureInPictureMessage = error.localizedDescription
                self.openFloatingPlayer(for: tab)
            }
        }
    }

    private func openFloatingPlayer(for tab: BrowserTab) {
        if let floatingPlayer {
            floatingPlayer.close()
            self.floatingPlayer = nil
        }
        let player = FloatingPiPController(tab: tab) { [weak self] in
            self?.floatingPlayer = nil
            self?.pictureInPictureMessage = "LeafOrLeave mini-player closed."
        }
        floatingPlayer = player
        tab.isPictureInPicture = true
        pictureInPictureMessage = "LeafOrLeave mini-player started."
        player.show()
    }
    func muteAll() { tabs?.tabs.forEach { $0.webView.evaluateJavaScript("document.querySelectorAll('video,audio').forEach(x=>x.muted=true)") } }
}

@MainActor
private final class FloatingPiPController: NSObject, NSWindowDelegate {
    private weak var tab: BrowserTab?
    private weak var originalHost: NSView?
    private let panel: NSPanel
    private let onClose: () -> Void
    private var isClosing = false

    init(tab: BrowserTab, onClose: @escaping () -> Void) {
        self.tab = tab
        self.originalHost = tab.webView.superview
        self.onClose = onClose
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.delegate = self
        panel.title = "Now Playing — \(tab.title)"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 320, height: 180)
        panel.isReleasedWhenClosed = false
    }

    func show() {
        guard let webView = tab?.webView else { return }
        let styleScript = """
        (() => {
          let style=document.getElementById('__leaf_floating_pip_style');
          if(!style){style=document.createElement('style');style.id='__leaf_floating_pip_style';document.documentElement.appendChild(style);}
          style.textContent=`html,body{background:#000!important;overflow:hidden!important}
          body *{visibility:hidden!important}
          video{visibility:visible!important;position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;object-fit:contain!important;z-index:2147483647!important;background:#000!important}`;
        })()
        """
        webView.evaluateJavaScript(styleScript)
        webView.removeFromSuperview()
        let host = NSView(frame: panel.contentView?.bounds ?? .zero)
        panel.contentView = host
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard !isClosing else { return }
        isClosing = true
        restoreWebView()
        panel.orderOut(nil)
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        close()
    }

    private func restoreWebView() {
        guard let tab else { return }
        let webView = tab.webView
        webView.evaluateJavaScript("document.getElementById('__leaf_floating_pip_style')?.remove()")
        webView.removeFromSuperview()
        if let originalHost {
            originalHost.subviews.forEach { $0.removeFromSuperview() }
            webView.translatesAutoresizingMaskIntoConstraints = false
            originalHost.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: originalHost.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: originalHost.trailingAnchor),
                webView.topAnchor.constraint(equalTo: originalHost.topAnchor),
                webView.bottomAnchor.constraint(equalTo: originalHost.bottomAnchor)
            ])
        }
        tab.isPictureInPicture = false
    }
}
