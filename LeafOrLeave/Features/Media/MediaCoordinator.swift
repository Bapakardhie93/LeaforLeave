import Foundation
import Observation
import WebKit

@MainActor @Observable
final class MediaCoordinator {
    weak var tabs: TabManager?
    var autoPictureInPicture = false
    var mediaTabs: [BrowserTab] { tabs?.tabs.filter { $0.mediaStatus.playbackState != .none } ?? [] }
    init(tabs: TabManager) { self.tabs = tabs }
    func togglePlayback(_ tab: BrowserTab) { tab.webView.evaluateJavaScript("(()=>{const m=document.querySelector('video,audio');if(!m)return false;m.paused?m.play():m.pause();return true})()") }
    func toggleMute(_ tab: BrowserTab) { tab.webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('video,audio')];const v=!a.every(x=>x.muted);a.forEach(x=>x.muted=v);return v})()") }
    func togglePiP(_ tab: BrowserTab) { tab.webView.evaluateJavaScript("(()=>{const v=document.querySelector('video');if(!v)return false;if(document.pictureInPictureElement)document.exitPictureInPicture();else if(v.requestPictureInPicture)v.requestPictureInPicture();return true})()") }
    func muteAll() { tabs?.tabs.forEach { $0.webView.evaluateJavaScript("document.querySelectorAll('video,audio').forEach(x=>x.muted=true)") } }
}
