import AppKit
import SwiftUI

struct BrowserSplitLayout<PanelContent: View>: View {
    let tabs: [BrowserTab]
    let fractions: [Double]
    let focusedTabID: UUID?
    let accentColor: Color
    let focus: (UUID) -> Void
    let remove: (UUID) -> Void
    let commitFractions: ([Double]) -> Void
    @ViewBuilder let panelContent: (BrowserTab) -> PanelContent

    @State private var transientFractions: [Double]?
    @State private var dragStartingFractions: [Double]?
    @State private var activeDivider: Int?

    var body: some View {
        GeometryReader { geometry in
            let dividerWidth = BrowserChromeMetrics.splitDividerHitWidth
            let availableWidth = max(
                0,
                geometry.size.width - dividerWidth * CGFloat(max(tabs.count - 1, 0))
            )
            let displayedFractions = normalizedDisplayedFractions

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    panel(for: tab)
                        .frame(width: panelWidth(at: index, availableWidth: availableWidth,
                                                 fractions: displayedFractions))
                    if index < tabs.count - 1 {
                        divider(after: index, availableWidth: availableWidth,
                                startingFractions: displayedFractions)
                            .frame(width: dividerWidth)
                    }
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .onChange(of: tabs.map(\.id)) { _, _ in resetDrag() }
        .onDisappear {
            resetDrag()
            NSCursor.arrow.set()
        }
    }

    private func panel(for tab: BrowserTab) -> some View {
        VStack(spacing: 0) {
            header(for: tab)
            panelContent(tab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Rectangle()
                .strokeBorder(
                    tab.id == focusedTabID ? accentColor.opacity(0.52) : Color.primary.opacity(0.055),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }

    private func header(for tab: BrowserTab) -> some View {
        HStack(spacing: 8) {
            Group {
                if tab.isLoading {
                    ProgressView().controlSize(.mini)
                } else if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .interpolation(.high)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 14, height: 14)

            Text(tab.title)
                .font(.system(size: 11.5, weight: tab.id == focusedTabID ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if tab.isMediaPlaying {
                Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(accentColor)
                    .accessibilityLabel(tab.isMediaMuted ? "Media muted" : "Media playing")
            }

            Button { remove(tab.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.primary.opacity(0.001), in: RoundedRectangle(cornerRadius: 7))
            .cursorHelp("Remove from split", animated: false)
            .accessibilityLabel("Remove \(tab.title) from split")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(height: BrowserChromeMetrics.splitHeaderHeight)
        .background(
            tab.id == focusedTabID
                ? accentColor.opacity(0.095)
                : Color.primary.opacity(0.028)
        )
        .overlay(alignment: .bottom) { Divider().opacity(0.45).allowsHitTesting(false) }
        .contentShape(Rectangle())
        .onTapGesture { focus(tab.id) }
    }

    private func divider(
        after index: Int,
        availableWidth: CGFloat,
        startingFractions: [Double]
    ) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .overlay {
                Capsule()
                    .fill(Color.primary.opacity(activeDivider == index ? 0.34 : 0.13))
                    .frame(width: activeDivider == index ? 2 : 1)
                    .padding(.vertical, 5)
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                (hovering ? NSCursor.resizeLeftRight : NSCursor.arrow).set()
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        if activeDivider != index || dragStartingFractions == nil {
                            activeDivider = index
                            dragStartingFractions = startingFractions
                        }
                        guard let dragStartingFractions else { return }
                        let resized = BrowserWindowState.resizedSplitFractions(
                            from: dragStartingFractions,
                            after: index,
                            translation: Double(value.translation.width),
                            availableWidth: Double(availableWidth),
                            minimumPanelWidth: BrowserChromeMetrics.minimumSplitPanelWidth
                        )
                        if transientFractions != resized { transientFractions = resized }
                    }
                    .onEnded { _ in
                        let finalFractions = transientFractions ?? startingFractions
                        resetDrag()
                        commitFractions(finalFractions)
                    }
            )
            .accessibilityLabel("Resize split panels")
    }

    private var normalizedDisplayedFractions: [Double] {
        let candidate = transientFractions ?? fractions
        guard candidate.count == tabs.count,
              candidate.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return Array(repeating: 1 / Double(max(tabs.count, 1)), count: tabs.count)
        }
        let total = candidate.reduce(0, +)
        guard total > 0 else {
            return Array(repeating: 1 / Double(max(tabs.count, 1)), count: tabs.count)
        }
        return candidate.map { $0 / total }
    }

    private func panelWidth(at index: Int, availableWidth: CGFloat, fractions: [Double]) -> CGFloat {
        guard fractions.indices.contains(index) else { return 0 }
        return max(0, availableWidth * CGFloat(fractions[index]))
    }

    private func resetDrag() {
        transientFractions = nil
        dragStartingFractions = nil
        activeDivider = nil
    }
}
