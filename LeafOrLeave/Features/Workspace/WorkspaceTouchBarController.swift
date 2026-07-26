import AppKit
import Observation
import QuartzCore
import WebKit

@MainActor
final class WorkspaceTouchBarController: NSObject, NSTouchBarDelegate {
    private static let contentIdentifier = NSTouchBarItem.Identifier("app.leaforleave.touchbar.content")

    let touchBar: NSTouchBar

    private let workspaceManager: WorkspaceManager
    private let tabManager: TabManager
    private let stripView = WorkspaceTouchBarStripView()
    private var displayedWorkspaceID: UUID?
    private var displayedTabActionsID: UUID?
    private var lastTappedTabID: UUID?
    private var lastTabTapDate = Date.distantPast
    private var workspaceTransitionTask: Task<Void, Never>?

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
                ($0.id, $0.title, $0.url?.absoluteString, $0.favicon, $0.isMediaPlaying,
                 $0.isMediaMuted, $0.isPinned, $0.isPrivate)
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
        if let displayedTabActionsID, tabManager.tab(id: displayedTabActionsID) != nil {
            showTabActions(for: displayedTabActionsID, in: displayedWorkspaceID, animated: false)
            return
        }
        showTabs(in: displayedWorkspaceID, animated: false)
    }

    private func showWorkspaces(animated: Bool) {
        displayedWorkspaceID = nil
        displayedTabActionsID = nil
        let selectedID = workspaceManager.selectedWorkspaceID
        let buttons = workspaceManager.workspaces.map { workspace in
            let selected = workspace.id == selectedID
            return makeButton(
                image: symbolImage(workspace.symbolName, fallback: "square.grid.2x2"),
                title: workspace.name,
                label: workspace.name,
                tint: accentColor(workspace.accentToken),
                selected: selected,
                width: 108
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
        displayedTabActionsID = nil
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
                title: workspace.name,
                label: workspace.name,
                tint: accent,
                selected: true,
                width: 108
            ) { button in
                button.playCelebration(color: accent)
            }
        )

        let tabsByID = Dictionary(uniqueKeysWithValues: tabManager.tabs.map { ($0.id, $0) })
        let ownedIDs = Set(tabManager.activeWindow?.tabIDs ?? [])
        let workspaceTabs = workspace.tabIDs.filter(ownedIDs.contains).compactMap { tabsByID[$0] }
        let tabWidth = touchBarTabWidth(for: workspaceTabs.count)

        for tab in workspaceTabs {
            let title = touchBarTitle(for: tab)
            let image = tab.favicon ?? symbolImage(
                tab.isPrivate ? "eye.slash.fill" : (tab.isMediaPlaying ? "waveform.circle.fill" : "globe"),
                fallback: "doc"
            )
            buttons.append(
                makeButton(
                    image: image,
                    title: title,
                    label: "Open \(title). Double tap for tab actions",
                    tint: accent,
                    selected: tab.id == tabManager.selectedTabID,
                    width: tabWidth
                ) { [weak self] button in
                    self?.selectTab(tab.id, in: workspaceID, source: button, accent: accent)
                }
            )
        }

        buttons.append(
            makeButton(
                image: symbolImage("plus", fallback: "add"),
                title: workspaceTabs.isEmpty ? "New Tab" : "",
                label: "Create a tab in \(workspace.name)",
                tint: accent,
                selected: false,
                width: workspaceTabs.isEmpty ? 104 : 42
            ) { [weak self] button in
                self?.createTab(in: workspaceID, source: button, accent: accent)
            }
        )

        stripView.setContent(
            buttons,
            accessibilityLabel: "Tabs in \(workspace.name)",
            animated: animated
        )
    }

    private func showTabActions(for tabID: UUID, in workspaceID: UUID, animated: Bool) {
        guard let tab = tabManager.tab(id: tabID),
              workspaceManager.workspaces.contains(where: { $0.id == workspaceID }) else {
            showTabs(in: workspaceID, animated: animated)
            return
        }
        displayedWorkspaceID = workspaceID
        displayedTabActionsID = tabID
        let accent = workspaceManager.workspaces
            .first(where: { $0.id == workspaceID })
            .map { accentColor($0.accentToken) } ?? .controlAccentColor

        var buttons: [AnimatedTouchBarButton] = []
        buttons.append(makeButton(
            image: symbolImage("chevron.backward", fallback: "arrow.left"),
            label: "Back to tabs", tint: .secondaryLabelColor, selected: false, width: 42
        ) { [weak self] button in
            button.playTapAnimation(color: accent)
            self?.showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: tab.favicon ?? symbolImage("globe", fallback: "doc"),
            title: touchBarTitle(for: tab), label: touchBarTitle(for: tab),
            tint: accent, selected: true, width: 150
        ) { button in button.playCelebration(color: accent) })
        buttons.append(makeButton(
            image: symbolImage("arrow.clockwise", fallback: "refresh"),
            label: "Reload tab", tint: .labelColor, selected: false, width: 42
        ) { [weak self, weak tab] button in
            button.playTapAnimation(color: accent)
            tab?.webView.reload()
            self?.showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: symbolImage("plus.square.on.square", fallback: "plus.square"),
            label: "Duplicate tab", tint: .labelColor, selected: false, width: 42
        ) { [weak self] button in
            button.playTapAnimation(color: accent)
            self?.tabManager.duplicateTab(id: tabID)
            self?.showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: symbolImage(tab.isPinned ? "pin.slash.fill" : "pin.fill", fallback: "pin.fill"),
            label: tab.isPinned ? "Unpin tab" : "Pin tab", tint: .labelColor,
            selected: false, width: 42
        ) { [weak self] button in
            button.playTapAnimation(color: accent)
            self?.tabManager.togglePin(id: tabID)
            self?.showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: symbolImage(tab.isMediaMuted ? "speaker.wave.2.fill" : "speaker.slash.fill", fallback: "speaker.slash"),
            label: tab.isMediaMuted ? "Unmute tab" : "Mute tab", tint: .labelColor,
            selected: false, width: 42
        ) { [weak self, weak tab] button in
            button.playTapAnimation(color: accent)
            tab?.webView.evaluateJavaScript("document.querySelectorAll('audio,video').forEach(m => m.muted = !m.muted)")
            self?.showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: symbolImage("rectangle.split.2x1", fallback: "rectangle.split.2x1"),
            label: "Duplicate into split screen", tint: .labelColor, selected: false, width: 42
        ) { [weak self, weak tab] button in
            guard let self, let owner = tabManager.ownerWindow(of: tabID), owner.canAddSplit else { return }
            button.playTapAnimation(color: accent)
            let copy = tabManager.createTab(
                opening: tab?.url,
                activate: false,
                in: owner.id,
                isPrivate: tab?.isPrivate == true
            )
            tabManager.addToSplit(tabID: copy.id, in: owner.id)
            showTabs(in: workspaceID, animated: true)
        })
        buttons.append(makeButton(
            image: symbolImage("xmark", fallback: "delete.left"),
            label: "Close tab", tint: .systemRed, selected: false, width: 42
        ) { [weak self] button in
            button.playTapAnimation(color: .systemRed)
            self?.tabManager.closeTab(id: tabID)
            self?.showTabs(in: workspaceID, animated: true)
        })

        stripView.setContent(
            buttons,
            accessibilityLabel: "Actions for \(touchBarTitle(for: tab))",
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

        workspaceTransitionTask?.cancel()
        workspaceTransitionTask = Task { @MainActor [weak self, weak button] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, button != nil else { return }
            self?.showTabs(in: workspaceID, animated: true)
        }
    }

    private func selectTab(
        _ tabID: UUID,
        in workspaceID: UUID,
        source button: AnimatedTouchBarButton,
        accent: NSColor
    ) {
        let now = Date()
        if lastTappedTabID == tabID, now.timeIntervalSince(lastTabTapDate) < 0.46 {
            lastTappedTabID = nil
            lastTabTapDate = .distantPast
            button.playCelebration(color: accent)
            showTabActions(for: tabID, in: workspaceID, animated: true)
            return
        }
        lastTappedTabID = tabID
        lastTabTapDate = now
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
        tabManager.activeWindow?.workspaceID = workspaceID
        let allIDs = tabManager.tabs.map(\.id)
        let existingIDs = tabManager.activeWindow?.tabIDs ?? []
        let validIDs = Set(existingIDs)
        workspaceManager.reconcileTabs(allIDs, assigningUnownedTo: workspaceID)

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
        doubleAction: ((AnimatedTouchBarButton) -> Void)? = nil,
        action: @escaping (AnimatedTouchBarButton) -> Void
    ) -> AnimatedTouchBarButton {
        let templateImage = image?.copy() as? NSImage
        templateImage?.isTemplate = true
        let button = AnimatedTouchBarButton(
            image: templateImage,
            title: title,
            action: action,
            doubleAction: doubleAction
        )
        button.setAccessibilityLabel(label)
        button.toolTip = label
        let usesDynamicLabelColor = tint == .labelColor || tint == .secondaryLabelColor
        let iconColor = selected || usesDynamicLabelColor
            ? NSColor.white.withAlphaComponent(selected ? 1 : 0.88)
            : tint.withAlphaComponent(0.95)
        button.setContentColors(
            icon: iconColor,
            text: .white,
            weight: selected ? .semibold : .medium
        )
        button.bezelColor = selected
            ? tint.withAlphaComponent(0.88)
            : NSColor.white.withAlphaComponent(0.09)
        button.layer?.cornerRadius = 8
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

    private func touchBarTabWidth(for count: Int) -> CGFloat {
        switch count {
        case 0: 132
        case 1: 174
        case 2: 152
        case 3: 126
        default: 108
        }
    }

    private func symbolImage(_ name: String, fallback: String) -> NSImage? {
        let source = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        guard let image = source?.copy() as? NSImage else { return nil }
        image.isTemplate = true
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
    private var renderGeneration = 0
    private var entryAnimationTasks: [Task<Void, Never>] = []

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
        renderGeneration &+= 1
        let generation = renderGeneration
        entryAnimationTasks.forEach { $0.cancel() }
        entryAnimationTasks.removeAll()
        let oldStack = stackView

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                oldStack.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, generation == self.renderGeneration else { return }
                    self.replaceStack(with: buttons, animated: true, generation: generation)
                }
            }
        } else {
            oldStack.layer?.removeAllAnimations()
            replaceStack(with: buttons, animated: false, generation: generation)
        }
    }

    private func replaceStack(
        with buttons: [AnimatedTouchBarButton],
        animated: Bool,
        generation: Int
    ) {
        guard generation == renderGeneration else { return }
        documentView.subviews.forEach { $0.removeFromSuperview() }
        installStack(buttons)
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        guard animated else { return }
        for (index, button) in buttons.enumerated() {
            button.alphaValue = 0
            button.layer?.transform = CATransform3DMakeTranslation(14, 0, 0)
            let task = Task { @MainActor [weak self, weak button] in
                try? await Task.sleep(for: .milliseconds(35 * index))
                guard let self, !Task.isCancelled, generation == renderGeneration,
                      let button, button.superview != nil else { return }
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
            entryAnimationTasks.append(task)
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
    private let doubleHandler: ((AnimatedTouchBarButton) -> Void)?
    private let iconView: NSImageView?
    private let titleLabel: NSTextField?
    private var lastActivation = Date.distantPast

    init(
        image: NSImage?,
        title: String,
        action: @escaping (AnimatedTouchBarButton) -> Void,
        doubleAction: ((AnimatedTouchBarButton) -> Void)? = nil
    ) {
        handler = action
        doubleHandler = doubleAction
        if let image {
            let view = NSImageView(image: image)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.imageScaling = .scaleProportionallyDown
            iconView = view
        } else {
            iconView = nil
        }
        if title.isEmpty {
            titleLabel = nil
        } else {
            let label = NSTextField(labelWithString: title)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.alignment = .left
            label.isSelectable = false
            titleLabel = label
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)
        bezelStyle = .rounded
        isBordered = true
        focusRingType = .none
        self.image = nil
        self.title = ""
        installContent()
        target = self
        self.action = #selector(performAction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installContent() {
        let views = [iconView, titleLabel].compactMap { $0 }
        guard !views.isEmpty else { return }
        let stack = TouchBarButtonContentView(views: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = titleLabel == nil ? 0 : 8
        addSubview(stack)

        if let iconView {
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 17),
                iconView.heightAnchor.constraint(equalToConstant: 17)
            ])
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        titleLabel?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 9),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -9)
        ])
    }

    func setContentColors(icon: NSColor, text: NSColor, weight: NSFont.Weight) {
        iconView?.contentTintColor = icon
        titleLabel?.textColor = text
        titleLabel?.font = .systemFont(ofSize: 12, weight: weight)
    }

    @objc private func performAction() {
        let now = Date()
        if let doubleHandler, now.timeIntervalSince(lastActivation) < 0.42 {
            lastActivation = .distantPast
            doubleHandler(self)
            return
        }
        lastActivation = now
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

@MainActor
private final class TouchBarButtonContentView: NSStackView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
