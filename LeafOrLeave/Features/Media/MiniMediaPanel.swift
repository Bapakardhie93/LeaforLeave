import SwiftUI

struct MiniMediaPanel: View {
    let coordinator: MediaCoordinator
    let select: (UUID) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Media").font(.headline)
            if coordinator.mediaTabs.isEmpty { ContentUnavailableView("No Active Media", systemImage: "play.rectangle") }
            ForEach(coordinator.mediaTabs) { tab in
                VStack(alignment: .leading) { Text(tab.title).lineLimit(1); Text(tab.url?.host ?? "Website").font(.caption).foregroundStyle(.secondary); HStack { Button("Back to Tab") { select(tab.id) }; Button { coordinator.togglePlayback(tab) } label: { Image(systemName: tab.isMediaPlaying ? "pause.fill" : "play.fill") }; Button { coordinator.toggleMute(tab) } label: { Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") }; if tab.hasVideo { Button("PiP") { coordinator.togglePiP(tab) } } } }
            }
        }.padding().frame(width: 360)
    }
}
