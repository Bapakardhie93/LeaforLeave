import SwiftUI

struct TabBarView: View {
    let manager: TabManager
    var visibleTabIDs: Set<UUID>?
    var compact = false
    var showFavicons = true
    var showMediaIndicators = true
    var animationStyle = AnimationStyle.gentle
    var reservesWindowControls = true
    let searchTabs: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 6) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 4) {
                            ForEach(visibleTabs) { tab in
                                TabItemView(
                                    tab: tab,
                                    selected: tab.id == manager.selectedTabID,
                                    compact: compact,
                                    showFavicon: showFavicons,
                                    showMediaIndicator: showMediaIndicators,
                                    availableWidth: tabWidth(in: geometry.size.width)
                                ) {
                                    manager.selectTab(id: tab.id)
                                } close: {
                                    manager.closeTab(id: tab.id)
                                }
                                .id(tab.id)
                                .transition(tabTransition)
                                .contextMenu {
                                    Button("Duplicate Tab") { manager.duplicateTab(id: tab.id) }
                                    Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                                        manager.togglePin(id: tab.id)
                                    }
                                    Divider()
                                    Button("Move Left") { manager.moveTab(id: tab.id, by: -1) }
                                    Button("Move Right") { manager.moveTab(id: tab.id, by: 1) }
                                    Divider()
                                    Button("Close Other Tabs") { manager.closeOtherTabs(keeping: tab.id) }
                                    Button("Close Tabs to the Right") { manager.closeTabsToRight(of: tab.id) }
                                    Button("Close Tab") { manager.closeTab(id: tab.id) }
                                }
                            }
                        }
                        .padding(.leading, reservesWindowControls ? BrowserChromeMetrics.trafficLightReserve : 8)
                        .padding(.vertical, 5)
                    }
                    .onChange(of: manager.selectedTabID) { _, selectedID in
                        guard let selectedID else { return }
                        withAnimation(tabAnimation) {
                            proxy.scrollTo(selectedID, anchor: .center)
                        }
                    }
                }

                tabBarActions
            }
            .padding(.trailing, 8)
        }
        .frame(height: compact ? 38 : BrowserChromeMetrics.tabBarHeight)
        .background {
            LinearGradient(
                colors: [Color.primary.opacity(0.035), Color.primary.opacity(0.065)],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
        }
        .overlay(alignment: .bottom) { Divider().opacity(0.34) }
        .animation(tabAnimation, value: manager.tabs.map(\.id))
    }

    private var tabBarActions: some View {
        HStack(spacing: 0) {
            Button(action: searchTabs) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: BrowserChromeMetrics.compactControlSize,
                           height: BrowserChromeMetrics.compactControlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .cursorHelp("Search Tabs (⌘⇧A)")
            .accessibilityLabel("Search tabs")

            Button { manager.createTab() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: BrowserChromeMetrics.compactControlSize,
                           height: BrowserChromeMetrics.compactControlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .cursorHelp("New Tab (⌘T)")
            .accessibilityLabel("New Tab")
        }
        .padding(.horizontal, 2)
        .background(LeafColors.chromeSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        }
    }

    private var visibleTabs: [BrowserTab] {
        manager.tabs.filter { visibleTabIDs?.contains($0.id) ?? true }
    }

    private func tabWidth(in totalWidth: CGFloat) -> CGFloat {
        let flexibleCount = max(visibleTabs.filter { !$0.isPinned }.count, 1)
        let pinnedCount = visibleTabs.filter(\.isPinned).count
        let leadingReserve = reservesWindowControls ? BrowserChromeMetrics.trafficLightReserve : 8
        let pinnedWidth = CGFloat(pinnedCount) * (BrowserChromeMetrics.pinnedTabWidth + 4)
        let tabGaps = CGFloat(max(visibleTabs.count - 1, 0)) * 4
        let actionReserve: CGFloat = 74
        let usableWidth = max(
            0,
            totalWidth - leadingReserve - pinnedWidth - tabGaps - actionReserve
        )
        let minimum = compact
            ? BrowserChromeMetrics.compactMinimumTabWidth
            : BrowserChromeMetrics.minimumTabWidth
        return min(
            BrowserChromeMetrics.maximumTabWidth,
            max(minimum, usableWidth / CGFloat(flexibleCount))
        )
    }

    private var tabAnimation: Animation? {
        switch animationStyle {
        case .none: nil
        case .system: .default
        case .gentle: .spring(response: 0.3, dampingFraction: 0.88)
        case .playful: .spring(response: 0.42, dampingFraction: 0.68)
        }
    }

    private var tabTransition: AnyTransition {
        guard animationStyle != .none else { return .identity }
        return .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .leading).combined(with: .opacity),
            removal: .scale(scale: 0.82).combined(with: .opacity)
        )
    }
}

private struct TabItemView: View {
    let tab: BrowserTab
    let selected: Bool
    let compact: Bool
    let showFavicon: Bool
    let showMediaIndicator: Bool
    let availableWidth: CGFloat
    let select: () -> Void
    let close: () -> Void
    @State private var isHovered = false
    @State private var closeIsHovered = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: select) {
                HStack(spacing: 7) {
                    tabIcon

                    if !tab.isPinned {
                        Text(tab.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }

                    if showMediaIndicator && tab.isMediaPlaying {
                        Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(LeafColors.accent)
                            .frame(width: 15)
                    }
                }
                .padding(.leading, tab.isPinned ? 0 : 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !tab.isPinned {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(
                    closeIsHovered ? Color.primary.opacity(0.10) : .clear,
                    in: Circle()
                )
                .opacity(selected || isHovered ? 1 : 0)
                .allowsHitTesting(selected || isHovered)
                .onHover { closeIsHovered = $0 }
                .padding(.trailing, 3)
                .cursorHelp("Close \(tab.title)", animated: false)
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .font(.system(size: 12, weight: selected ? .medium : .regular))
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .frame(
            width: tab.isPinned ? BrowserChromeMetrics.pinnedTabWidth : availableWidth,
            height: compact ? BrowserChromeMetrics.compactTabHeight : BrowserChromeMetrics.tabHeight
        )
        .background(tabBackground, in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.tabCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrowserChromeMetrics.tabCornerRadius, style: .continuous)
                .strokeBorder(selected ? Color.primary.opacity(0.09) : Color.clear)
        }
        .shadow(color: selected ? .black.opacity(0.15) : .clear, radius: 4, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: BrowserChromeMetrics.tabCornerRadius, style: .continuous))
        .onHover { value in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = value
            }
        }
        .cursorHelp(tab.title, animated: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var tabIcon: some View {
        if tab.isLoading {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 14, height: 14)
        } else if showFavicon, let favicon = tab.favicon {
            Image(nsImage: favicon)
                .resizable()
                .interpolation(.high)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            Image(systemName: tab.isPinned ? "pin.fill" : "globe")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
    }

    private var tabBackground: Color {
        if selected { return LeafColors.chromeSelected }
        if isHovered { return LeafColors.chromeHover.opacity(0.8) }
        return Color.primary.opacity(0.018)
    }
}
