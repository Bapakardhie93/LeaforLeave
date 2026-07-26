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
    private var applyTask: Task<Void, Never>?
    private var applyRevision = 0
    func select(_ value: EqualizerPreset) { preset = value; gains = value.gains; preamp = -max(0, gains.max() ?? 0) }
    func apply(to webView: WKWebView) {
        applyRevision += 1
        let revision = applyRevision
        let configurationEnabled = enabled
        let configurationGains = gains
        let configurationPreamp = preamp
        applyTask?.cancel()
        let script = """
        const controller = window.__leafEqualizerController;
        if (!controller) {
          return {status:'unavailable', message:'Reload this tab once to install the audio processor.'};
        }
        return await controller.apply({enabled, gains, preamp});
        """
        applyTask = Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            try? await Task.sleep(for: .milliseconds(18))
            guard !Task.isCancelled else { return }
            do {
                let value = try await webView.callAsyncJavaScript(
                    script,
                    arguments: [
                        "enabled": configurationEnabled,
                        "gains": configurationGains,
                        "preamp": configurationPreamp
                    ],
                    in: nil,
                    contentWorld: .page
                )
                guard !Task.isCancelled, revision == self.applyRevision else { return }
                let response = value as? [String: Any]
                self.compatibility = EqualizerCompatibility(rawValue: response?["status"] as? String ?? "failed") ?? .failed
                self.statusMessage = response?["message"] as? String ?? "Equalizer failed without a website response."
            } catch {
                guard !Task.isCancelled, revision == self.applyRevision else { return }
                self.compatibility = .failed
                self.statusMessage = error.localizedDescription
            }
        }
    }
}
