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
    var statusMessage = "Open a playing HTML5 audio or video, then enable the equalizer."
    func select(_ value: EqualizerPreset) { preset = value; gains = value.gains; preamp = -max(0, gains.max() ?? 0) }
    func apply(to webView: WKWebView) {
        let values = gains.map { String($0) }.joined(separator: ",")
        let active = enabled ? "true" : "false"
        let script = """
        try {
          const media=[...document.querySelectorAll('audio,video')]
            .filter(element => element.readyState >= 2)
            .sort((a,b)=>(Number(!b.paused)-Number(!a.paused)) ||
                         (Number(!b.muted && b.volume > 0)-Number(!a.muted && a.volume > 0)) ||
                         ((b.clientWidth*b.clientHeight)-(a.clientWidth*a.clientHeight)));
          const m=media[0];
          if(!m)return {status:'unavailable',message:'No HTML5 audio or video was found in this page.'};
          if(m.mediaKeys)return {status:'protectedMedia',message:'Protected DRM media cannot be processed.'};
          const C=window.AudioContext||window.webkitAudioContext;
          if(!C)return {status:'unavailable',message:'Web Audio is not available on this page.'};
          if(!window.__leafEQ || window.__leafEQ.media!==m){
            if(window.__leafEQ){
              try { window.__leafEQ.source.disconnect(); } catch (_) {}
              try { await window.__leafEQ.c.close(); } catch (_) {}
            }
            const c=new C({latencyHint:'interactive'}), source=c.createMediaElementSource(m);
            const filters=[32,64,125,250,500,1000,2000,4000,8000,16000].map(f=>{
              const node=c.createBiquadFilter(); node.type='peaking'; node.frequency.value=f; node.Q.value=1.2; return node;
            });
            const wet=c.createGain(), dry=c.createGain(), output=c.createGain();
            source.connect(filters[0]); source.connect(dry);
            filters.forEach((node,index)=>node.connect(filters[index+1]||wet));
            wet.connect(output); dry.connect(output); output.connect(c.destination);
            window.__leafEQ={c,source,filters,wet,dry,output,media:m};
          }
          const eq=window.__leafEQ;
          [\(values)].forEach((gain,index)=>eq.filters[index].gain.value=\(active)?gain:0);
          eq.wet.gain.value=\(active)?1:0;
          eq.dry.gain.value=\(active)?0:1;
          eq.output.gain.value=Math.pow(10,\(preamp)/20);
          if(eq.c.state==='suspended')await eq.c.resume();
          return eq.c.state==='running'
            ? {status:'available',message:'Equalizer is active on '+(m.currentSrc||'the current media')+'.'}
            : {status:'blockedBySite',message:'Playback must be started by the user before Web Audio can run.'};
        }catch(error){
          return {status:'failed',message:error.name+': '+error.message};
        }
        """
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            do {
                let value = try await webView.callAsyncJavaScript(
                    script,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                let response = value as? [String: Any]
                self.compatibility = EqualizerCompatibility(rawValue: response?["status"] as? String ?? "failed") ?? .failed
                self.statusMessage = response?["message"] as? String ?? "Equalizer failed without a website response."
            } catch {
                self.compatibility = .failed
                self.statusMessage = error.localizedDescription
            }
        }
    }
}
