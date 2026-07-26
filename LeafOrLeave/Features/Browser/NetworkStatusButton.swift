import SwiftUI

struct NetworkStatusButton: View {
    @Environment(\.leafToolbarIconSize) private var toolbarIconSize
    let network: NetworkMonitor
    @State private var isHovered = false

    var body: some View {
        Button { network.refreshLatency() } label: {
            HStack(spacing: 5) {
                Image(systemName: network.isConnected ? "wifi" : "wifi.slash")
                    .font(.system(size: max(11, toolbarIconSize - 1), weight: .medium))
                Text(network.latencyMS.map { "\($0) ms" } ?? "—")
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .frame(height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
            .background(isHovered ? LeafColors.chromeHover : LeafColors.chromeSurface,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .cursorHelp("Live network latency • Click to refresh")
        .accessibilityLabel(network.latencyMS.map { "Network latency \($0) milliseconds" } ?? "Network latency unavailable")
    }

    private var statusColor: Color {
        guard network.isConnected, let latency = network.latencyMS else { return .red }
        if latency < 80 { return LeafColors.secure }
        if latency < 180 { return .orange }
        return .red
    }
}
