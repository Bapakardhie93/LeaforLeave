import Foundation
import WebKit

struct FormSnapshot: Codable, Equatable { let values: [String: String]; let capturedAt: Date }

@MainActor
struct FormSnapshotService {
    func capture(from webView: WKWebView) async -> FormSnapshot? {
        let script = """
        (() => { const out={}; document.querySelectorAll('input,textarea,select').forEach((e,i)=>{ const t=(e.type||'').toLowerCase(); if(['password','hidden','file'].includes(t)||/card|cvv|payment/i.test(e.name||''))return; if(!['text','search','email','url','tel','number','checkbox','radio',''].includes(t)&&e.tagName!=='TEXTAREA'&&e.tagName!=='SELECT')return; const k=e.name||e.id||('field-'+i); out[k]=(t==='checkbox'||t==='radio')?String(e.checked):String(e.value||''); }); return out; })()
        """
        guard let values = try? await webView.evaluateJavaScript(script) as? [String: String] else { return nil }
        return FormSnapshot(values: values, capturedAt: Date())
    }
}
