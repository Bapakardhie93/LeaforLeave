import Foundation
import Observation
import WebKit

@MainActor @Observable
final class EqualizerViewModel {
    var enabled = false
    var preset = EqualizerPreset.all[0]
    var preamp = 0.0
    var gains = Array(repeating: 0.0, count: 10)
    var compatibility: EqualizerCompatibility = .unavailable
    func select(_ value: EqualizerPreset) { preset = value; gains = value.gains; preamp = -max(0, gains.max() ?? 0) }
    func apply(to webView: WKWebView) {
        guard enabled else { webView.evaluateJavaScript("window.__leafEQ?.close()", completionHandler: nil); return }
        let values = gains.map { String($0) }.joined(separator: ",")
        let script = """
        (()=>{try{const m=document.querySelector('audio,video');if(!m||m.mediaKeys)return 'protectedMedia';const C=window.AudioContext||window.webkitAudioContext;if(!C)return 'unavailable';if(!window.__leafEQ){const c=new C(),s=c.createMediaElementSource(m),fs=[32,64,125,250,500,1000,2000,4000,8000,16000].map((f,i)=>{const q=c.createBiquadFilter();q.type='peaking';q.frequency.value=f;q.Q.value=1.2;return q});s.connect(fs[0]);fs.forEach((x,i)=>x.connect(fs[i+1]||c.destination));window.__leafEQ={c,fs}};[\(values)].forEach((g,i)=>window.__leafEQ.fs[i].gain.value=g);return 'available'}catch(e){return 'blockedBySite'}})()
        """
        webView.evaluateJavaScript(script) { [weak self] value, _ in Task { @MainActor in self?.compatibility = EqualizerCompatibility(rawValue: value as? String ?? "failed") ?? .failed } }
    }
}
