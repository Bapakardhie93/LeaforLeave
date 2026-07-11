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
        let values = gains.map { String($0) }.joined(separator: ",")
        let active = enabled ? "true" : "false"
        let script = """
        (async()=>{try{
          const m=document.querySelector('audio,video');
          if(!m||m.mediaKeys)return 'protectedMedia';
          const C=window.AudioContext||window.webkitAudioContext;
          if(!C)return 'unavailable';
          if(!window.__leafEQ){
            const c=new C(), source=c.createMediaElementSource(m);
            const filters=[32,64,125,250,500,1000,2000,4000,8000,16000].map(f=>{
              const node=c.createBiquadFilter(); node.type='peaking'; node.frequency.value=f; node.Q.value=1.2; return node;
            });
            const output=c.createGain(); source.connect(filters[0]);
            filters.forEach((node,index)=>node.connect(filters[index+1]||output)); output.connect(c.destination);
            window.__leafEQ={c,filters,output,media:m};
          }
          const eq=window.__leafEQ;
          if(eq.media!==m)return 'blockedBySite';
          [\(values)].forEach((gain,index)=>eq.filters[index].gain.value=\(active)?gain:0);
          eq.output.gain.value=1;
          if(eq.c.state==='suspended')await eq.c.resume();
          return eq.c.state==='running'?'available':'blockedBySite';
        }catch(error){return 'blockedBySite'}})()
        """
        webView.evaluateJavaScript(script) { [weak self] value, _ in Task { @MainActor in self?.compatibility = EqualizerCompatibility(rawValue: value as? String ?? "failed") ?? .failed } }
    }
}
