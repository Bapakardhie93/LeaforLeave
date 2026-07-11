import AppKit
import SwiftUI

struct DownloadsListView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: DownloadManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if manager.records.isEmpty { emptyState } else { downloadList }
        }
        .frame(minWidth: 620, idealWidth: 700, minHeight: 460, idealHeight: 560)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 19)).foregroundStyle(LeafColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloads").font(.headline)
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if manager.records.contains(where: { $0.status == .completed }) {
                Button("Clear Completed") { manager.clearCompleted() }.buttonStyle(.bordered)
            }
            Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                .buttonStyle(.plain).background(.white.opacity(0.07), in: Circle()).help("Close")
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 42, weight: .light)).foregroundStyle(LeafColors.accent)
                .frame(width: 82, height: 82)
                .background(LeafColors.accent.opacity(0.10), in: Circle())
            Text("No downloads yet").font(.title3.bold())
            Text("Files you download will appear here with progress, status, and quick actions.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            Button("Open Downloads Folder") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    private var downloadList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(manager.records) { item in DownloadRow(item: item, manager: manager) }
            }
            .padding(16)
        }
    }

    private var summary: String {
        let active = manager.records.filter { $0.status == .downloading }.count
        return active > 0 ? "\(active) active • \(manager.records.count) total" : "\(manager.records.count) recent item\(manager.records.count == 1 ? "" : "s")"
    }
}

private struct DownloadRow: View {
    let item: DownloadRecord
    let manager: DownloadManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
                .frame(width: 42, height: 42).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(item.filename).font(.subheadline.weight(.semibold)).lineLimit(1); Spacer(); Text(statusText).font(.caption).foregroundStyle(color) }
                HStack { Text(item.sourceHost); Text("•"); Text(item.createdAt, style: .relative) }
                    .font(.caption).foregroundStyle(.secondary)
                if item.status == .downloading { ProgressView(value: item.progress).tint(LeafColors.accent) }
                if let message = item.errorMessage, item.status == .failed { Text(message).font(.caption2).foregroundStyle(.red).lineLimit(1) }
            }
            if item.status == .completed {
                Button { manager.open(item) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open")
                Button { manager.reveal(item) } label: { Image(systemName: "folder") }.help("Show in Finder")
            } else if item.status == .downloading {
                Button { manager.cancel(item.id) } label: { Image(systemName: "xmark.circle") }.help("Cancel")
            }
            Button(role: .destructive) { manager.remove(item.id) } label: { Image(systemName: "trash") }.help("Remove from list")
        }
        .buttonStyle(.borderless).padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.055)) }
    }

    private var icon: String { switch item.status { case .completed: "checkmark.circle.fill"; case .failed: "exclamationmark.triangle.fill"; case .cancelled: "xmark.circle.fill"; default: "arrow.down.circle.fill" } }
    private var color: Color { switch item.status { case .completed: LeafColors.secure; case .failed: .red; case .cancelled: .secondary; default: LeafColors.accent } }
    private var statusText: String { item.status == .downloading ? "\(Int(item.progress * 100))%" : item.status.rawValue.capitalized }
}
