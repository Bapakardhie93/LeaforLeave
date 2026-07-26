import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    // Deliberately does not conform to public.data/file-url: this is an
    // in-process interaction token, not a document Finder may create.
    static let leafBrowserTab = UTType(exportedAs: "app.leaforleave.browser-tab")
}

private struct TabDragPayload: Codable {
    let tabID: UUID
    let sourceWindowID: UUID
    let title: String
}

private enum TabDragItemProvider {
    static func make(tab: BrowserTab, sourceWindowID: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        let payload = TabDragPayload(tabID: tab.id, sourceWindowID: sourceWindowID, title: tab.title)
        let data = try? JSONEncoder().encode(payload)
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.leafBrowserTab.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, data == nil ? CocoaError(.coderInvalidValue) : nil)
            return nil
        }
        return provider
    }
}

private struct TabDragPreview: View {
    let tab: BrowserTab

    var body: some View {
        HStack(spacing: 9) {
            tabIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let host = tab.url?.host {
                    Text(host)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09))
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    @ViewBuilder
    private var tabIcon: some View {
        if let favicon = tab.favicon {
            Image(nsImage: favicon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: tab.isPrivate ? "eye.slash.fill" : "globe")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }
}

struct TabBarView: View {
    @Environment(\.leafAccentColor) private var accentColor
    let manager: TabManager
    let window: BrowserWindowState
    var visibleTabIDs: Set<UUID>?
    var compact = false
    var showFavicons = true
    var showMediaIndicators = true
    var animationStyle = AnimationStyle.gentle
    var reservesWindowControls = true
    var newTabShortcut = "⌘T"
    var searchTabsShortcut = "⇧⌘A"
    let searchTabs: () -> Void
    let detachTab: (UUID) -> Void
    let openInSplit: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let tabs = visibleTabs
            HStack(spacing: 6) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 4) {
                            ForEach(tabs) { tab in
                                TabItemView(
                                    tab: tab,
                                    selected: tab.id == window.focusedTabID,
                                    compact: compact,
                                    showFavicon: showFavicons,
                                    showMediaIndicator: showMediaIndicators,
                                    availableWidth: tabWidth(in: geometry.size.width, tabs: tabs)
                                ) {
                                    manager.selectTab(id: tab.id, in: window.id)
                                } close: {
                                    manager.closeTab(id: tab.id)
                                }
                                .id(tab.id)
                                .transition(tabTransition)
                                .contextMenu {
                                    Button("Open in Split") { openInSplit(tab.id) }
                                        .disabled(window.visibleTabIDs.contains(tab.id) || !window.canAddSplit)
                                    Button("Move Tab to New Window") { detachTab(tab.id) }
                                    Divider()
                                    Button("Duplicate Tab") { manager.duplicateTab(id: tab.id, in: window.id) }
                                    Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                                        manager.togglePin(id: tab.id)
                                    }
                                    Divider()
                                    Button("Move Left") { manager.moveTab(id: tab.id, by: -1, in: window.id) }
                                    Button("Move Right") { manager.moveTab(id: tab.id, by: 1, in: window.id) }
                                    Divider()
                                    Button("Close Other Tabs") { manager.closeOtherTabs(keeping: tab.id) }
                                    Button("Close Tabs to the Right") { manager.closeTabsToRight(of: tab.id) }
                                    Button("Close Tab") { manager.closeTab(id: tab.id) }
                                }
                                .onDrag {
                                    manager.beginDragging(tabID: tab.id, from: window.id)
                                    TabDragReleaseMonitor.shared.begin(manager: manager, sourceWindowID: window.id) {
                                        detachTab(tab.id)
                                    }
                                    return TabDragItemProvider.make(tab: tab, sourceWindowID: window.id)
                                } preview: {
                                    TabDragPreview(tab: tab)
                                }
                                .onDrop(
                                    of: [.leafBrowserTab],
                                    delegate: TabItemDropDelegate(
                                        manager: manager,
                                        windowID: window.id,
                                        targetTabID: tab.id,
                                        axis: .horizontal,
                                        targetExtent: tab.isPinned
                                            ? BrowserChromeMetrics.pinnedTabWidth
                                            : tabWidth(in: geometry.size.width, tabs: tabs)
                                    )
                                )
                                .opacity(manager.draggedTabID == tab.id ? 0.48 : 1)
                                .scaleEffect(manager.draggedTabID == tab.id ? 0.97 : 1)
                                .zIndex(manager.draggedTabID == tab.id ? 2 : 0)
                            }
                        }
                        .padding(.leading, reservesWindowControls ? BrowserChromeMetrics.trafficLightReserve : 8)
                        .padding(.vertical, 5)
                    }
                    .onChange(of: window.focusedTabID) { _, selectedID in
                        guard let selectedID else { return }
                        withAnimation(tabAnimation) {
                            proxy.scrollTo(selectedID, anchor: .center)
                        }
                    }
                }

                tabBarActions
            }
            .padding(.trailing, 8)
            .onDrop(of: [.leafBrowserTab], delegate: TabBarDropDelegate(manager: manager, windowID: window.id))
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
        .overlay(alignment: .bottom) { Divider().opacity(0.34).allowsHitTesting(false) }
        .overlay {
            if manager.dragTargetWindowID == window.id,
               manager.dragSourceWindowID != window.id {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.055))
                    .padding(3)
                    .allowsHitTesting(false)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(accentColor.opacity(0.42), lineWidth: 1.5)
                            .padding(3)
                            .allowsHitTesting(false)
                    }
            }
        }
        .animation(tabAnimation, value: window.tabIDs)
        .animation(.easeOut(duration: 0.16), value: manager.draggedTabID)
    }

    private var tabBarActions: some View {
        HStack(spacing: 0) {
            Button(action: searchTabs) {
                ZStack {
                    Color.clear
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: BrowserChromeMetrics.compactControlSize,
                       height: BrowserChromeMetrics.compactControlSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .cursorHelp("Search Tabs (\(searchTabsShortcut))")
            .accessibilityLabel("Search tabs")

            Button { manager.createTab(in: window.id) } label: {
                ZStack {
                    Color.clear
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(width: BrowserChromeMetrics.compactControlSize,
                       height: BrowserChromeMetrics.compactControlSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .cursorHelp("New Tab (\(newTabShortcut))")
            .accessibilityLabel("New Tab")
        }
        .padding(.horizontal, 2)
        .background(LeafColors.chromeSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
                .allowsHitTesting(false)
        }
    }

    private var visibleTabs: [BrowserTab] {
        manager.tabs(in: window.id).filter { visibleTabIDs?.contains($0.id) ?? true }
    }

    private func tabWidth(in totalWidth: CGFloat, tabs: [BrowserTab]) -> CGFloat {
        let flexibleCount = max(tabs.filter { !$0.isPinned }.count, 1)
        let pinnedCount = tabs.filter(\.isPinned).count
        let leadingReserve = reservesWindowControls ? BrowserChromeMetrics.trafficLightReserve : 8
        let pinnedWidth = CGFloat(pinnedCount) * (BrowserChromeMetrics.pinnedTabWidth + 4)
        let tabGaps = CGFloat(max(tabs.count - 1, 0)) * 4
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

struct VerticalTabBarView: View {
    @Environment(\.leafAccentColor) private var accentColor
    let manager: TabManager
    let window: BrowserWindowState
    var visibleTabIDs: Set<UUID>?
    var compact = false
    var showFavicons = true
    var showMediaIndicators = true
    var newTabShortcut = "⌘T"
    var searchTabsShortcut = "⇧⌘A"
    let searchTabs: () -> Void
    let detachTab: (UUID) -> Void
    let openInSplit: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Tabs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(tabs.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Spacer()
                verticalAction("magnifyingglass", help: "Search Tabs (\(searchTabsShortcut))", action: searchTabs)
                verticalAction("plus", help: "New Tab (\(newTabShortcut))") {
                    manager.createTab(in: window.id)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 40)

            Divider().opacity(0.45)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(tabs) { tab in
                            VerticalTabItemView(
                                tab: tab,
                                selected: tab.id == window.focusedTabID,
                                compact: compact,
                                showFavicon: showFavicons,
                                showMediaIndicator: showMediaIndicators,
                                select: { manager.selectTab(id: tab.id, in: window.id) },
                                close: { manager.closeTab(id: tab.id) }
                            )
                            .id(tab.id)
                            .contextMenu {
                                Button("Open in Split") { openInSplit(tab.id) }
                                    .disabled(window.visibleTabIDs.contains(tab.id) || !window.canAddSplit)
                                Button("Move Tab to New Window") { detachTab(tab.id) }
                                Divider()
                                Button("Duplicate Tab") { manager.duplicateTab(id: tab.id, in: window.id) }
                                Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { manager.togglePin(id: tab.id) }
                                Divider()
                                Button("Move Up") { manager.moveTab(id: tab.id, by: -1, in: window.id) }
                                Button("Move Down") { manager.moveTab(id: tab.id, by: 1, in: window.id) }
                                Divider()
                                Button("Close Other Tabs") { manager.closeOtherTabs(keeping: tab.id) }
                                Button("Close Tab") { manager.closeTab(id: tab.id) }
                            }
                            .onDrag {
                                manager.beginDragging(tabID: tab.id, from: window.id)
                                TabDragReleaseMonitor.shared.begin(manager: manager, sourceWindowID: window.id) {
                                    detachTab(tab.id)
                                }
                                return TabDragItemProvider.make(tab: tab, sourceWindowID: window.id)
                            } preview: {
                                TabDragPreview(tab: tab)
                            }
                            .onDrop(
                                of: [.leafBrowserTab],
                                delegate: TabItemDropDelegate(
                                    manager: manager,
                                    windowID: window.id,
                                    targetTabID: tab.id,
                                    axis: .vertical,
                                    targetExtent: compact ? 34 : 38
                                )
                            )
                            .opacity(manager.draggedTabID == tab.id ? 0.48 : 1)
                            .scaleEffect(manager.draggedTabID == tab.id ? 0.97 : 1)
                        }
                    }
                    .padding(7)
                }
                .onChange(of: window.focusedTabID) { _, selectedID in
                    guard let selectedID else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
        .frame(width: compact ? 184 : 218)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) { Divider().opacity(0.45).allowsHitTesting(false) }
        .overlay {
            if manager.dragTargetWindowID == window.id,
               manager.dragSourceWindowID != window.id {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(accentColor.opacity(0.42), lineWidth: 1.5)
                    }
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.leafBrowserTab], delegate: TabBarDropDelegate(manager: manager, windowID: window.id))
        .animation(.easeOut(duration: 0.16), value: manager.draggedTabID)
    }

    private var tabs: [BrowserTab] {
        manager.tabs(in: window.id).filter { visibleTabIDs?.contains($0.id) ?? true }
    }

    private func verticalAction(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Color.clear
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .foregroundStyle(.secondary)
        .cursorHelp(help)
        .accessibilityLabel(help)
    }
}

private struct VerticalTabItemView: View {
    @Environment(\.leafAccentColor) private var accentColor
    let tab: BrowserTab
    let selected: Bool
    let compact: Bool
    let showFavicon: Bool
    let showMediaIndicator: Bool
    let select: () -> Void
    let close: () -> Void
    @State private var hovered = false
    @State private var closeHovered = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: select) {
                HStack(spacing: 9) {
                    tabIcon
                    Text(tab.title)
                        .font(.system(size: compact ? 11.5 : 12.5, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    if showMediaIndicator && tab.isMediaPlaying {
                        Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                    Color.clear.frame(width: tab.isPinned ? 2 : 24, height: 1)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: compact ? 34 : 38, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !tab.isPinned {
                Button(action: close) {
                    ZStack {
                        Color.clear
                        Image(systemName: "xmark").font(.system(size: 9.5, weight: .semibold))
                    }
                    .frame(width: 25, height: 25)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(closeHovered ? Color.primary.opacity(0.1) : .clear, in: Circle())
                .padding(.trailing, 5)
                .opacity(selected || hovered ? 1 : 0)
                .allowsHitTesting(selected || hovered)
                .onHover { closeHovered = $0 }
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .background(
            selected ? accentColor.opacity(0.16) : (hovered ? Color.primary.opacity(0.065) : .clear),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? accentColor.opacity(0.28) : .clear)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { hovered = $0 }
        .cursorHelp(tab.title, animated: false)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var tabIcon: some View {
        if tab.isLoading {
            ProgressView().controlSize(.mini).frame(width: 15, height: 15)
        } else if tab.isPrivate {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 15)
        } else if showFavicon, let favicon = tab.favicon {
            Image(nsImage: favicon)
                .resizable().interpolation(.high)
                .frame(width: 15, height: 15)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: tab.isPinned ? "pin.fill" : "globe")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 15)
        }
    }
}

private struct TabItemView: View {
    @Environment(\.leafAccentColor) private var accentColor
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
        ZStack {
            Button(action: select) {
                Group {
                    if tab.isPinned {
                        tabIcon
                    } else {
                        ZStack {
                            Text(tab.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 42)
                                .layoutPriority(1)

                            HStack(spacing: 3) {
                                tabIcon
                                if showMediaIndicator && tab.isMediaPlaying {
                                    Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(accentColor)
                                }
                                Spacer(minLength: 0)
                                Color.clear.frame(width: 30, height: 1)
                            }
                            .padding(.leading, 9)
                        }
                    }
                }
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
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
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
                .allowsHitTesting(false)
        }
        .shadow(color: selected ? .black.opacity(0.15) : .clear, radius: 4, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: BrowserChromeMetrics.tabCornerRadius, style: .continuous))
        .onHover { isHovered = $0 }
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
        } else if tab.isPrivate {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 14)
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

@MainActor
final class TabDragReleaseMonitor {
    static let shared = TabDragReleaseMonitor()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var releasePollTimer: Timer?
    private weak var manager: TabManager?
    private var detach: (() -> Void)?
    private var isFinishing = false
    private var startedAt = Date.distantPast
    private var sourceWindowID: UUID?
    private var sourceFrame: CGRect?

    func begin(manager: TabManager, sourceWindowID: UUID, detach: @escaping () -> Void) {
        stopMonitoring()
        self.manager = manager
        self.detach = detach
        self.sourceWindowID = sourceWindowID
        sourceFrame = manager.window(id: sourceWindowID)?.frame ?? NSApp.keyWindow?.frame
        isFinishing = false
        startedAt = .now
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .keyDown]) { [weak self] event in
            if event.type == .keyDown, event.keyCode == 53 {
                self?.cancel()
            } else if event.type == .leftMouseUp {
                self?.finishAfterDropProcessing(at: NSEvent.mouseLocation)
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in self?.finishAfterDropProcessing(at: location) }
        }
        let reference = TabDragMonitorReference(self)
        let timer = Timer(timeInterval: 0.016, repeats: true) { _ in
            Task { @MainActor in reference.value?.finishWhenMouseIsReleased() }
        }
        releasePollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finishWhenMouseIsReleased() {
        guard Date.now.timeIntervalSince(startedAt) >= 0.08,
              manager?.draggedTabID != nil,
              NSEvent.pressedMouseButtons & 1 == 0 else { return }
        finishAfterDropProcessing(at: NSEvent.mouseLocation)
    }

    private func finishAfterDropProcessing(at pointer: CGPoint) {
        guard !isFinishing else { return }
        isFinishing = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(20))
            guard let self else { return }

            guard let manager, manager.draggedTabID != nil else {
                stopMonitoring()
                return
            }

            let currentSourceWindowID = manager.dragSourceWindowID
            let explicitTarget = manager.dragTargetWindowID.flatMap { targetID -> BrowserWindowState? in
                guard let target = manager.window(id: targetID),
                      target.frame?.insetBy(dx: -10, dy: -10).contains(pointer) == true else { return nil }
                return target
            }
            let geometricTarget = manager.windows.first { state in
                state.frame?.insetBy(dx: -4, dy: -4).contains(pointer) == true
                    && state.id != currentSourceWindowID
            } ?? manager.windows.first { state in
                state.frame?.insetBy(dx: -4, dy: -4).contains(pointer) == true
            }
            if let target = explicitTarget ?? geometricTarget {
                if target.id != currentSourceWindowID {
                    _ = manager.completeDrop(in: target.id)
                } else {
                    manager.clearDragState()
                }
                stopMonitoring()
                return
            }

            let shouldDetach = TabDragDetachDecision.shouldDetach(
                hasDraggedTab: true,
                dragTargetWindowID: nil,
                sourceWindowID: sourceWindowID,
                pointer: pointer,
                sourceFrame: sourceFrame
            )
            let detachAction = detach
            if shouldDetach { detachAction?() }
            manager.clearDragState()
            stopMonitoring()
        }
    }

    private func cancel() {
        manager?.cancelDragging()
        stopMonitoring()
    }

    private func stopMonitoring() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        releasePollTimer?.invalidate()
        localMonitor = nil
        globalMonitor = nil
        releasePollTimer = nil
        detach = nil
        sourceWindowID = nil
        sourceFrame = nil
        isFinishing = false
        startedAt = .distantPast
    }
}

private final class TabDragMonitorReference: @unchecked Sendable {
    nonisolated(unsafe) weak var value: TabDragReleaseMonitor?

    init(_ value: TabDragReleaseMonitor) {
        self.value = value
    }
}

enum TabDragDetachDecision {
    static func shouldDetach(
        hasDraggedTab: Bool,
        dragTargetWindowID: UUID?,
        sourceWindowID: UUID?,
        pointer: CGPoint,
        sourceFrame: CGRect?
    ) -> Bool {
        guard hasDraggedTab else { return false }
        if let dragTargetWindowID, dragTargetWindowID != sourceWindowID { return false }
        if let sourceFrame, sourceFrame.insetBy(dx: -8, dy: -8).contains(pointer) { return false }
        return true
    }
}

private struct TabBarDropDelegate: DropDelegate {
    let manager: TabManager
    let windowID: UUID

    func dropEntered(info: DropInfo) {
        manager.setDragTarget(windowID: windowID, targeted: true)
    }

    func dropExited(info: DropInfo) {
        manager.setDragTarget(windowID: windowID, targeted: false)
    }

    func performDrop(info: DropInfo) -> Bool {
        manager.completeDrop(in: windowID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct TabItemDropDelegate: DropDelegate {
    enum Axis { case horizontal, vertical }

    let manager: TabManager
    let windowID: UUID
    let targetTabID: UUID
    let axis: Axis
    let targetExtent: CGFloat

    func dropEntered(info: DropInfo) {
        manager.setDragTarget(windowID: windowID, targeted: true)
        previewMove(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        previewMove(info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        manager.completeDrop(
            in: windowID,
            relativeTo: targetTabID,
            placeAfter: isAfterTarget(info)
        )
    }

    private func previewMove(_ info: DropInfo) {
        manager.previewDraggedTab(
            in: windowID,
            relativeTo: targetTabID,
            placeAfter: isAfterTarget(info)
        )
    }

    private func isAfterTarget(_ info: DropInfo) -> Bool {
        let location = axis == .horizontal ? info.location.x : info.location.y
        return location > targetExtent / 2
    }
}
