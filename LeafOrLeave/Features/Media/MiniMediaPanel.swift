import SwiftUI
import WebKit

struct MiniMediaPanel: View {
    let coordinator: MediaCoordinator
    let select: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Media controls", systemImage: "play.rectangle.on.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.mediaTabs.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if coordinator.mediaTabs.isEmpty {
                ContentUnavailableView("No Active Media", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ForEach(coordinator.mediaTabs) { tab in
                    MediaControlCard(
                        tab: tab,
                        coordinator: coordinator,
                        select: { select(tab.id) }
                    )
                }
            }

            if let message = coordinator.pictureInPictureMessage {
                Label(message, systemImage: message.contains("started") ? "checkmark.circle.fill" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(message.contains("started") ? LeafColors.secure : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .frame(width: 410)
    }
}

private struct MediaControlCard: View {
    let tab: BrowserTab
    let coordinator: MediaCoordinator
    let select: () -> Void

    @State private var currentTime = 0.0
    @State private var duration = 0.0
    @State private var isSeeking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: tab.hasVideo ? "play.rectangle.fill" : "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LeafColors.accent)
                    .frame(width: 34, height: 34)
                    .background(LeafColors.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(LeafFormatting.displayHost(tab.url))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: select) {
                    Image(systemName: "arrow.up.forward.app")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .cursorHelp("Return to media tab")
            }

            VStack(spacing: 5) {
                Slider(
                    value: Binding(
                        get: { min(currentTime, max(duration, 0)) },
                        set: { currentTime = $0 }
                    ),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing { seek(to: currentTime) }
                    }
                )
                .tint(LeafColors.accent)
                .disabled(duration <= 0)

                HStack {
                    Text(LeafFormatting.mediaTime(currentTime))
                    Spacer()
                    Text(duration > 0 ? LeafFormatting.mediaTime(duration) : "--:--")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                mediaButton(
                    tab.isMediaPlaying ? "pause.fill" : "play.fill",
                    tab.isMediaPlaying ? "Pause" : "Play"
                ) { coordinator.togglePlayback(tab) }
                mediaButton(
                    tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    tab.isMediaMuted ? "Unmute" : "Mute"
                ) { coordinator.toggleMute(tab) }
                Spacer()
                if tab.hasVideo {
                    Button {
                        coordinator.togglePiP(tab)
                    } label: {
                        Label("Mini-player", systemImage: "pip.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                    }
                    .buttonStyle(.plain)
                    .background(LeafColors.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(LeafColors.accent)
                    .cursorHelp("Open floating mini-player")
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
                .allowsHitTesting(false)
        }
        .task { await monitorPlayback() }
    }

    private func mediaButton(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 31, height: 30)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .cursorHelp(help)
    }

    private func monitorPlayback() async {
        while !Task.isCancelled {
            let script = """
            (() => {
              const media=[...document.querySelectorAll('video,audio')]
                .filter(m=>m.readyState>=1)
                .sort((a,b)=>(Number(!b.paused)-Number(!a.paused)) ||
                             ((b.clientWidth*b.clientHeight)-(a.clientWidth*a.clientHeight)));
              const m=media[0];
              return m ? {current:Number(m.currentTime)||0,duration:Number.isFinite(m.duration)?m.duration:0} : null;
            })()
            """
            if let result = try? await tab.webView.evaluateJavaScript(script) as? [String: Double],
               !isSeeking {
                currentTime = result["current"] ?? 0
                duration = result["duration"] ?? 0
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func seek(to value: Double) {
        tab.webView.evaluateJavaScript("""
        (()=>{const m=[...document.querySelectorAll('video,audio')].find(x=>!x.paused)||
        document.querySelector('video,audio');if(m&&Number.isFinite(m.duration)){m.currentTime=\(value);return true}return false})()
        """)
    }
}
