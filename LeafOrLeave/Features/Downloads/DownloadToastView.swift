import SwiftUI

struct DownloadToastView: View {
    let record: DownloadRecord
    let openDownloads: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, options: .repeating,
                                  isActive: record.status == .downloading)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(record.filename).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(action: dismiss) {
                    Image(systemName: "xmark").frame(width: 22, height: 22)
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .accessibilityLabel("Dismiss download notification")
            }

            if record.status == .downloading {
                HStack(spacing: 9) {
                    ProgressView(value: record.progress).tint(LeafColors.accent)
                    Text("\(Int(record.progress * 100))%")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            } else if let error = record.errorMessage, record.status == .failed {
                Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            Button("Show Downloads", action: openDownloads)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LeafColors.accent)
        }
        .padding(14)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(Color.primary.opacity(0.10)).allowsHitTesting(false) }
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch record.status {
        case .queued: "Preparing download…"
        case .downloading: "Downloading…"
        case .paused: "Download paused"
        case .completed: "Download complete"
        case .failed: "Download failed"
        case .cancelled: "Download cancelled"
        }
    }

    private var icon: String {
        switch record.status {
        case .queued, .downloading: "arrow.down"
        case .paused: "pause.fill"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        case .cancelled: "xmark"
        }
    }

    private var color: Color {
        switch record.status {
        case .queued, .downloading: LeafColors.accent
        case .paused: .orange
        case .completed: LeafColors.secure
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}

struct DownloadToolbarButton: View {
    @Environment(\.leafAccentColor) private var accentColor
    @Environment(\.leafToolbarIconSize) private var toolbarIconSize
    let activeCount: Int
    let latestProgress: Double
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if activeCount > 0 {
                    Circle()
                        .trim(from: 0, to: max(0.03, latestProgress))
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 27, height: 27)
                        .animation(.easeOut(duration: 0.2), value: latestProgress)
                }
                Image(systemName: activeCount > 0 ? "arrow.down" : "arrow.down.circle")
                    .font(.system(size: toolbarIconSize, weight: .semibold))
                if activeCount > 1 {
                    Text("\(activeCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(accentColor, in: Circle())
                        .offset(x: 11, y: -10)
                }
            }
            .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
        .foregroundStyle(activeCount > 0 ? accentColor : .secondary)
        .background(isHovered ? LeafColors.chromeHover : .clear,
                    in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.toolbarControlCornerRadius, style: .continuous))
        .onHover { isHovered = $0 }
        .cursorHelp(activeCount > 0 ? "\(activeCount) active download\(activeCount == 1 ? "" : "s")" : "Downloads")
        .accessibilityLabel(activeCount > 0 ? "\(activeCount) active downloads" : "Downloads")
    }
}
