import SwiftUI

struct DownloadsListView: View {
    let manager: DownloadManager
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("Downloads").font(.title2.bold()); Spacer(); Button("Clear Completed") { manager.clearCompleted() } }
            if manager.records.isEmpty { ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Downloaded files will appear here.")) }
            else { List(manager.records) { item in
                HStack { VStack(alignment: .leading) { Text(item.filename).lineLimit(1); Text("\(item.sourceHost) • \(item.status.rawValue.capitalized)").font(.caption).foregroundStyle(.secondary); if item.status == .downloading { ProgressView(value: item.progress) } }; Spacer(); if item.status == .completed { Button("Open") { manager.open(item) }; Button("Reveal") { manager.reveal(item) } }; Button { manager.remove(item.id) } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
            } }
        }.padding().frame(width: 520, height: 420)
    }
}
