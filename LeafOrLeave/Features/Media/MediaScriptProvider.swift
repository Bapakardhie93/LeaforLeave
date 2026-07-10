import WebKit

enum MediaScriptProvider {
    static let name = "leafMedia"
    static var script: WKUserScript { WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false) }
    static let source = """
    (()=>{ if(window.__leafMedia)return; window.__leafMedia=true; const send=e=>{const m=e.target; webkit.messageHandlers.leafMedia.postMessage({playing:!m.paused&&!m.ended,video:m.tagName==='VIDEO',muted:m.muted,pip:document.pictureInPictureElement===m,duration:Number.isFinite(m.duration)?m.duration:0,current:m.currentTime||0});}; ['play','pause','ended','volumechange','enterpictureinpicture','leavepictureinpicture','loadedmetadata'].forEach(n=>document.addEventListener(n,send,true)); })();
    """
}
