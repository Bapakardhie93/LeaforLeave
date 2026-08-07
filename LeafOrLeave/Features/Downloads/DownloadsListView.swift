import AppKit
import SwiftUI

struct DownloadsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.leafAccentColor) private var accentColor
    @Environment(\.leafAppearance) private var appearance
    let manager: DownloadManager

    @State private var search = ""
    @State private var filter = DownloadListFilter.all

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 0) {
                header
                overview
                controls
                content
            }
        }
        .frame(minWidth: 720, idealWidth: 820, minHeight: 540, idealHeight: 660)
        .animation(.snappy(duration: 0.22), value: filter)
        .animation(.snappy(duration: 0.22), value: manager.records.count)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if appearance.isLiquidGlass {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(nsColor: .windowBackgroundColor).opacity(0.20)
                RadialGradient(
                    colors: [accentColor.opacity(0.09), .clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 460
                )
            }
        } else {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [accentColor.opacity(0.045), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "arrow.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: accentColor.opacity(0.24), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text("Downloads")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(headerSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openDownloadsFolder()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if completedCount > 0 {
                Menu {
                    Button("Clear Completed", systemImage: "checkmark.circle") {
                        manager.clearCompleted()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 27, height: 27)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("More download actions")
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close Downloads")
            .accessibilityLabel("Close Downloads")
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    private var overview: some View {
        HStack(spacing: 10) {
            DownloadSummaryItem(
                title: "Active",
                value: "\(activeCount)",
                detail: activeCount == 0 ? "Nothing downloading" : activeProgressText,
                icon: "arrow.down.circle.fill",
                color: accentColor
            )
            DownloadSummaryItem(
                title: "Completed",
                value: "\(completedCount)",
                detail: completedCount == 1 ? "File ready" : "Files ready",
                icon: "checkmark.circle.fill",
                color: LeafColors.secure
            )
            DownloadSummaryItem(
                title: "Downloaded",
                value: downloadedSize,
                detail: "Across recent items",
                icon: "externaldrive.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 18)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search downloads", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Clear download search")
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: 280)
            .frame(height: 36)
            .background(Color.primary.opacity(appearance.isLiquidGlass ? 0.075 : 0.04), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.065))
                    .allowsHitTesting(false)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(DownloadListFilter.allCases) { item in
                    filterButton(item)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(appearance.isLiquidGlass ? 0.075 : 0.035), in: Capsule())
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var content: some View {
        if manager.records.isEmpty {
            emptyState
        } else if filteredRecords.isEmpty {
            noResultsState
        } else {
            downloadList
        }
    }

    private var downloadList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 21) {
                ForEach(groupedRecords) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            Text(group.title)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.primary.opacity(0.09), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 3)

                        VStack(spacing: 8) {
                            ForEach(group.records) { item in
                                ModernDownloadRow(item: item, manager: manager)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.automatic)
    }

    private var emptyState: some View {
        DownloadEmptyState(
            title: "Ready when you are",
            detail: "Files you download will appear here with live progress and quick actions.",
            icon: "arrow.down.doc",
            buttonTitle: "Open Downloads Folder",
            buttonAction: openDownloadsFolder
        )
    }

    private var noResultsState: some View {
        DownloadEmptyState(
            title: "No matching downloads",
            detail: "Try another search or show all download statuses.",
            icon: "magnifyingglass",
            buttonTitle: "Reset Filters",
            buttonAction: {
                search = ""
                filter = .all
            }
        )
    }

    private func filterButton(_ item: DownloadListFilter) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            Text(item.title)
                .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 11)
                .frame(height: 27)
                .background(selected ? accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var filteredRecords: [DownloadRecord] {
        manager.records.filter { record in
            filter.includes(record.status)
                && (search.isEmpty
                    || record.filename.localizedCaseInsensitiveContains(search)
                    || record.sourceHost.localizedCaseInsensitiveContains(search))
        }
    }

    private var groupedRecords: [DownloadDateGroup] {
        var result: [DownloadDateGroup] = []
        for record in filteredRecords {
            let title = dateGroupTitle(record.createdAt)
            if result.last?.title == title {
                result[result.count - 1].records.append(record)
            } else {
                result.append(DownloadDateGroup(title: title, records: [record]))
            }
        }
        return result
    }

    private var activeRecords: [DownloadRecord] {
        manager.records.filter { [.queued, .downloading, .paused].contains($0.status) }
    }

    private var activeCount: Int { activeRecords.count }
    private var completedCount: Int { manager.records.filter { $0.status == .completed }.count }

    private var activeProgressText: String {
        guard !activeRecords.isEmpty else { return "Nothing downloading" }
        let average = activeRecords.map(\.progress).reduce(0, +) / Double(activeRecords.count)
        return "\(LeafFormatting.percentage(average)) overall"
    }

    private var downloadedSize: String {
        let total = manager.records.reduce(Int64(0)) { partial, record in
            partial + max(record.bytesWritten, record.status == .completed ? record.totalBytes : 0)
        }
        return total > 0 ? LeafFormatting.fileSize(total) : "0 KB"
    }

    private var headerSummary: String {
        if activeCount > 0 {
            return "\(activeCount) active • \(manager.records.count) recent"
        }
        return manager.records.isEmpty
            ? "Your recent files in one place"
            : "\(manager.records.count) recent item\(manager.records.count == 1 ? "" : "s")"
    }

    private func dateGroupTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    private func openDownloadsFolder() {
        guard let folder = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first else { return }
        NSWorkspace.shared.open(folder)
    }
}

private enum DownloadListFilter: String, CaseIterable, Identifiable {
    case all, active, completed, issues

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func includes(_ status: DownloadStatus) -> Bool {
        switch self {
        case .all: true
        case .active: [.queued, .downloading, .paused].contains(status)
        case .completed: status == .completed
        case .issues: status == .failed || status == .cancelled
        }
    }
}

private struct DownloadDateGroup: Identifiable {
    let title: String
    var records: [DownloadRecord]
    var id: String { title }
}

private struct DownloadSummaryItem: View {
    @Environment(\.leafAppearance) private var appearance
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    appearance.isLiquidGlass
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(Color.primary.opacity(0.032))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
                .allowsHitTesting(false)
        }
    }
}

private struct ModernDownloadRow: View {
    @Environment(\.leafAccentColor) private var accentColor
    @Environment(\.leafAppearance) private var appearance
    let item: DownloadRecord
    let manager: DownloadManager
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            fileIcon

            VStack(alignment: .leading, spacing: 6) {
                Text(item.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.status == .downloading || item.status == .queued {
                    progress
                } else {
                    metadata
                }

                if item.status == .failed, let message = item.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 7) {
                statusLabel
                actions
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    appearance.isLiquidGlass
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(Color.primary.opacity(hovered ? 0.055 : 0.028))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(hovered ? 0.12 : 0.06))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(hovered ? 0.09 : 0.025), radius: hovered ? 12 : 5, y: hovered ? 5 : 2)
        .scaleEffect(hovered ? 1.003 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { value in
            withAnimation(.easeOut(duration: 0.14)) { hovered = value }
        }
        .onTapGesture(count: 2) {
            if item.status == .completed { manager.open(item) }
        }
        .contextMenu {
            if item.status == .completed {
                if canOpenSafely {
                    Button("Open") { manager.open(item) }
                }
                Button("Show in Finder") { manager.reveal(item) }
                Divider()
            }
            if item.status == .downloading || item.status == .queued {
                Button("Cancel Download", role: .destructive) { manager.cancel(item.id) }
            } else {
                Button("Remove from List", role: .destructive) { manager.remove(item.id) }
            }
        }
    }

    private var fileIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: fileSymbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 42, height: 42)
                .background(statusColor.opacity(0.11), in: Circle())

            Image(systemName: statusSymbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(statusColor, in: Circle())
                .overlay { Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5) }
                .offset(x: 2, y: 2)
        }
        .frame(width: 44, height: 44)
    }

    private var statusLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
        }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(statusColor)
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            Text(sizeText)
            Text("•")
            Text(item.sourceHost)
                .lineLimit(1)
            Text("•")
            Text(item.createdAt, style: .relative)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }

    private var progress: some View {
        VStack(spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(max(item.progress, 0), 1))
                }
            }
            .frame(height: 5)

            HStack {
                Text(transferText)
                Spacer()
                Text(LeafFormatting.percentage(item.progress))
                    .monospacedDigit()
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var actions: some View {
        Menu {
            if item.status == .completed {
                if canOpenSafely {
                    Button("Open", systemImage: "arrow.up.forward.app") {
                        manager.open(item)
                    }
                }
                Button("Show in Finder", systemImage: "folder") {
                    manager.reveal(item)
                }
                Divider()
            } else if item.status == .downloading || item.status == .queued {
                Button("Cancel Download", systemImage: "xmark", role: .destructive) {
                    manager.cancel(item.id)
                }
            }
            if item.status != .downloading && item.status != .queued {
                Button("Remove from List", systemImage: "trash", role: .destructive) {
                    manager.remove(item.id)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 25, height: 21)
                .background(Color.primary.opacity(hovered ? 0.065 : 0.035), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
        .accessibilityLabel("Actions for \(item.filename)")
    }

    private var fileSymbol: String {
        switch URL(fileURLWithPath: item.filename).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "svg": "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv": "film.fill"
        case "mp3", "m4a", "wav", "aac", "flac": "waveform"
        case "zip", "rar", "7z", "tar", "gz": "archivebox.fill"
        case "pdf": "doc.richtext.fill"
        case "dmg", "pkg": "shippingbox.fill"
        default: "doc.fill"
        }
    }

    private var canOpenSafely: Bool {
        !["app", "pkg", "dmg", "command"].contains(
            URL(fileURLWithPath: item.filename).pathExtension.lowercased()
        )
    }

    private var statusSymbol: String {
        switch item.status {
        case .queued, .downloading: "arrow.down"
        case .paused: "pause.fill"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        case .cancelled: "xmark"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued, .downloading: accentColor
        case .paused: .orange
        case .completed: LeafColors.secure
        case .failed: .red
        case .cancelled: .secondary
        }
    }

    private var statusText: String {
        switch item.status {
        case .queued: "Preparing"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    private var sizeText: String {
        let size = max(item.bytesWritten, item.totalBytes)
        return size > 0 ? LeafFormatting.fileSize(size) : "Size unavailable"
    }

    private var transferText: String {
        let completed = item.bytesWritten > 0 ? LeafFormatting.fileSize(item.bytesWritten) : "0 KB"
        guard item.totalBytes > 0 else { return completed }
        return "\(completed) of \(LeafFormatting.fileSize(item.totalBytes))"
    }
}

private struct DownloadEmptyState: View {
    @Environment(\.leafAccentColor) private var accentColor
    let title: String
    let detail: String
    let icon: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(accentColor.opacity(0.1))
                Circle().strokeBorder(accentColor.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 76, height: 76)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            Button(buttonTitle, action: buttonAction)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
