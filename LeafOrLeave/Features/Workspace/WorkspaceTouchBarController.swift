import AppKit
import Observation
import QuartzCore

@MainActor
final class WorkspaceTouchBarController: NSObject, NSTouchBarDelegate {
    private static let contentIdentifier = NSTouchBarItem.Identifier("app.leaforleave.touchbar.content")

    let touchBar: NSTouchBar

    private let workspaceManager: WorkspaceManager
    private let tabManager: TabManager
    private let stripView = WorkspaceTouchBarStripView()
    private var displayedWorkspaceID: UUID?

    init(workspaces: WorkspaceManager, tabs: TabManager) {
        workspaceManager = workspaces
        tabManager = tabs

        let bar = NSTouchBar()
        touchBar = bar

        super.init()

        bar.customizationIdentifier = .init("app.leaforleave.touchbar")
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            Self.contentIdentifier,
            .flexibleSpace,
            .otherItemsProxy
        ]
        bar.customizationAllowedItemIdentifiers = [Self.contentIdentifier]
        bar.customizationRequiredItemIdentifiers = [Self.contentIdentifier]
        bar.principalItemIdentifier = Self.contentIdentifier

        showWorkspaces(animated: false)
        observeState()
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == Self.contentIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "LeafOrLeave Workspaces"
        item.view = stripView
        return item
    }

    private func observeState() {
        withObservationTracking {
            _ = workspaceManager.selectedWorkspaceID
            _ = workspaceManager.workspaces.map {
                ($0.id, $0.name, $0.symbolName, $0.accentToken, $0.tabIDs, $0.selectedTabID)
            }
            _ = tabManager.selectedTabID
            _ = tabManager.tabs.map {
                ($0.id, $0.title, $0.url?.absoluteString, $0.favicon, $0.isMediaPlaying)
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                refreshVisibleContent()
                observeState()
            }
        }
    }

    private func refreshVisibleContent() {
        guard let displayedWorkspaceID,
              workspaceManager.workspaces.contains(where: { $0.id == displayedWorkspaceID }) else {
            showWorkspaces(animated: false)
            return
        }
        showTabs(in: displayedWorkspaceID, animated: false)
    }

    private func showWorkspaces(animated: Bool) {
        displayedWorkspaceID = nil
        let selectedID = workspaceManager.selectedWorkspaceID
        let buttons = workspaceManager.workspaces.map { workspace in
            let selected = workspace.id == selectedID
            return makeButton(
                image: symbolImage(workspace.symbolName, fallback: "square.grid.2x2"),
                label: workspace.name,
                tint: accentColor(workspace.accentToken),
                selected: selected,
                width: 48
            ) { [weak self] button in
                self?.openWorkspace(workspace.id, source: button)
            }
        }

        stripView.setContent(
            buttons,
            accessibilityLabel: "LeafOrLeave workspaces",
            animated: animated
        )
    }

    private func showTabs(in workspaceID: UUID, animated: Bool) {
        guard let workspace = workspaceManager.workspaces.first(where: { $0.id == workspaceID }) else {
            showWorkspaces(animated: animated)
            return
        }

        displayedWorkspaceID = workspaceID
        let accent = accentColor(workspace.accentToken)
        var buttons: [AnimatedTouchBarButton] = []

        buttons.append(
            makeButton(
                image: symbolImage("chevron.backward", fallback: "arrow.left"),
                label: "All workspaces",
                tint: .secondaryLabelColor,
                selected: false,
                width: 42
            ) { [weak self] button in
                button.playTapAnimation(color: accent)
                self?.showWorkspaces(animated: true)
            }
        )

        buttons.append(
            makeButton(
                image: symbolImage(workspace.symbolName, fallback: "square.grid.2x2"),
                label: workspace.name,
                tint: accent,
                selected: true,
                width: 46
            ) { button in
                button.playCelebration(color: accent)
            }
        )

        let tabsByID = Dictionary(uniqueKeysWithValues: tabManager.tabs.map { ($0.id, $0) })
        let workspaceTabs = workspace.tabIDs.compactMap { tabsByID[$0] }

        for tab in workspaceTabs {
            let title = touchBarTitle(for: tab)
            let image = tab.favicon ?? symbolImage(
                tab.isMediaPlaying ? "waveform.circle.fill" : "globe",
                fallback: "doc"
            )
            buttons.append(
                makeButton(
                    image: image,
                    title: title,
                    label: "Open \(title)",
                    tint: accent,
                    selected: tab.id == tabManager.selectedTabID,
                    width: 132
                ) { [weak self] button in
                    self?.selectTab(tab.id, in: workspaceID, source: button, accent: accent)
                }
            )
        }

        if workspaceTabs.isEmpty {
            buttons.append(
                makeButton(
                    image: symbolImage("plus", fallback: "add"),
                    title: "New Tab",
                    label: "Create a tab in \(workspace.name)",
                    tint: accent,
                    selected: false,
                    width: 104
                ) { [weak self] button in
                    self?.createTab(in: workspaceID, source: button, accent: accent)
                }
            )
        }

        stripView.setContent(
            buttons,
            accessibilityLabel: "Tabs in \(workspace.name)",
            animated: animated
        )
    }

    private func openWorkspace(_ workspaceID: UUID, source button: AnimatedTouchBarButton) {
        guard workspaceManager.workspaces.contains(where: { $0.id == workspaceID }) else { return }
        let accent = workspaceManager.workspaces
            .first(where: { $0.id == workspaceID })
            .map { accentColor($0.accentToken) } ?? .controlAccentColor

        button.playCelebration(color: accent)
        activateWorkspace(workspaceID)

        Task { @MainActor [weak self, weak button] in
            try? await Task.sleep(for: .milliseconds(150))
            guard button != nil else { return }
            self?.showTabs(in: workspaceID, animated: true)
        }
    }

    private func selectTab(
        _ tabID: UUID,
        in workspaceID: UUID,
        source button: AnimatedTouchBarButton,
        accent: NSColor
    ) {
        button.playTapAnimation(color: accent)
        if workspaceManager.selectedWorkspaceID != workspaceID {
            workspaceManager.selectWorkspace(id: workspaceID)
        }
        tabManager.selectTab(id: tabID)
        workspaceManager.rememberSelection(tabID)
    }

    private func createTab(
        in workspaceID: UUID,
        source button: AnimatedTouchBarButton,
        accent: NSColor
    ) {
        button.playCelebration(color: accent)
        workspaceManager.selectWorkspace(id: workspaceID)
        let tab = tabManager.createTab()
        workspaceManager.moveTab(tab.id, to: workspaceID)
        showTabs(in: workspaceID, animated: true)
    }

    private func activateWorkspace(_ workspaceID: UUID) {
        workspaceManager.selectWorkspace(id: workspaceID)
        let existingIDs = tabManager.tabs.map(\.id)
        let validIDs = Set(existingIDs)
        workspaceManager.reconcileTabs(existingIDs, assigningUnownedTo: workspaceID)

        guard let workspace = workspaceManager.workspaces.first(where: { $0.id == workspaceID }) else {
            return
        }
        if let selected = workspace.selectedTabID, validIDs.contains(selected) {
            tabManager.selectTab(id: selected)
        } else if let first = workspace.tabIDs.first(where: validIDs.contains) {
            tabManager.selectTab(id: first)
        } else {
            let tab = tabManager.createTab()
            workspaceManager.moveTab(tab.id, to: workspaceID)
        }
    }

    private func makeButton(
        image: NSImage?,
        title: String = "",
        label: String,
        tint: NSColor,
        selected: Bool,
        width: CGFloat,
        action: @escaping (AnimatedTouchBarButton) -> Void
    ) -> AnimatedTouchBarButton {
        let button = AnimatedTouchBarButton(image: image, title: title, action: action)
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.contentTintColor = selected ? .white : tint
        button.bezelColor = selected ? tint.withAlphaComponent(0.82) : nil
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.font = .systemFont(ofSize: 12, weight: selected ? .semibold : .medium)
        button.lineBreakMode = .byTruncatingTail
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    private func touchBarTitle(for tab: BrowserTab) -> String {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != "New Tab" { return trimmed }
        if let host = tab.url?.host, !host.isEmpty { return host }
        return "New Tab"
    }

    private func symbolImage(_ name: String, fallback: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private func accentColor(_ token: String) -> NSColor {
        switch token.lowercased() {
        case "blue": .systemBlue
        case "cyan": .systemCyan
        case "green": .systemGreen
        case "orange": .systemOrange
        case "pink": .systemPink
        case "red": .systemRed
        case "yellow": .systemYellow
        default: .systemPurple
        }
    }
}

@MainActor
private final class WorkspaceTouchBarStripView: NSView {
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private var stackView = NSStackView()
    private var documentWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none

        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.wantsLayer = true
        scrollView.documentView = documentView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 650),
            heightAnchor.constraint(equalToConstant: 30),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            documentView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])

        installStack([])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(
        _ buttons: [AnimatedTouchBarButton],
        accessibilityLabel: String,
        animated: Bool
    ) {
        setAccessibilityLabel(accessibilityLabel)
        let oldStack = stackView

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                oldStack.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.replaceStack(oldStack, with: buttons, animated: true)
                }
            }
        } else {
            replaceStack(oldStack, with: buttons, animated: false)
        }
    }

    private func replaceStack(
        _ oldStack: NSStackView,
        with buttons: [AnimatedTouchBarButton],
        animated: Bool
    ) {
        oldStack.removeFromSuperview()
        installStack(buttons)
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        guard animated else { return }
        for (index, button) in buttons.enumerated() {
            button.alphaValue = 0
            button.layer?.transform = CATransform3DMakeTranslation(14, 0, 0)
            Task { @MainActor [weak button] in
                try? await Task.sleep(for: .milliseconds(35 * index))
                guard let button else { return }
                await NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.24
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    button.animator().alphaValue = 1
                }
                let slide = CABasicAnimation(keyPath: "transform.translation.x")
                slide.fromValue = 14
                slide.toValue = 0
                slide.duration = 0.24
                slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
                button.layer?.add(slide, forKey: "leaf.slideIn")
                button.layer?.transform = CATransform3DIdentity
            }
        }
    }

    private func installStack(_ views: [NSView]) {
        let newStack = NSStackView(views: views)
        newStack.translatesAutoresizingMaskIntoConstraints = false
        newStack.orientation = .horizontal
        newStack.alignment = .centerY
        newStack.spacing = 7
        newStack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        newStack.alphaValue = 1
        documentView.addSubview(newStack)
        stackView = newStack

        documentWidthConstraint?.isActive = false
        documentWidthConstraint = documentView.widthAnchor.constraint(
            equalTo: newStack.widthAnchor
        )
        documentWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            newStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            newStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            newStack.centerYAnchor.constraint(equalTo: documentView.centerYAnchor)
        ])
    }
}

@MainActor
private final class AnimatedTouchBarButton: NSButton {
    private let handler: (AnimatedTouchBarButton) -> Void

    init(image: NSImage?, title: String, action: @escaping (AnimatedTouchBarButton) -> Void) {
        handler = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        bezelStyle = .rounded
        isBordered = true
        self.image = image
        self.title = title
        target = self
        self.action = #selector(performAction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performAction() {
        handler(self)
    }

    func playTapAnimation(color: NSColor) {
        guard let layer else { return }
        layer.removeAnimation(forKey: "leaf.tap")
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1, 0.88, 1.1, 1]
        bounce.keyTimes = [0, 0.24, 0.62, 1]
        bounce.duration = 0.34
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(bounce, forKey: "leaf.tap")
        playGlow(color: color, strong: false)
    }

    func playCelebration(color: NSColor) {
        guard let layer else { return }
        layer.removeAnimation(forKey: "leaf.celebration")
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1, 0.82, 1.2, 0.96, 1.08, 1]
        bounce.keyTimes = [0, 0.16, 0.42, 0.63, 0.82, 1]
        bounce.duration = 0.52
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(bounce, forKey: "leaf.celebration")
        playGlow(color: color, strong: true)
    }

    private func playGlow(color: NSColor, strong: Bool) {
        guard let layer else { return }
        layer.shadowColor = color.cgColor
        layer.shadowRadius = strong ? 9 : 6
        layer.shadowOffset = .zero

        let glow = CAKeyframeAnimation(keyPath: "shadowOpacity")
        glow.values = [0, strong ? 0.95 : 0.7, 0]
        glow.keyTimes = [0, 0.35, 1]
        glow.duration = strong ? 0.58 : 0.38
        layer.add(glow, forKey: "leaf.glow")
        layer.shadowOpacity = 0
    }
}
