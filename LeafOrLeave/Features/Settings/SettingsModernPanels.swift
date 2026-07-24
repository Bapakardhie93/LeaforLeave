import AppKit
import SwiftUI
import WebKit

struct WorkspaceSettingsPanel: View {
    @Bindable var workspaces: WorkspaceManager
    @State private var selectedID: UUID?
    @State private var showsCreateWorkspace = false

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your workspaces")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Each workspace keeps its own tabs, selected tab, icon, color, and home page.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showsCreateWorkspace = true
                } label: {
                    Label("New Workspace", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(LeafColors.accent)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(workspaces.workspaces) { workspace in
                    workspaceCard(workspace)
                }
            }

            if let workspace = selectedWorkspace {
                workspaceEditor(workspace)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if selectedWorkspace == nil {
                selectedID = workspaces.selectedWorkspaceID ?? workspaces.workspaces.first?.id
            }
        }
        .sheet(isPresented: $showsCreateWorkspace) {
            WorkspaceCreator { name, symbol, accent in
                if let id = workspaces.createWorkspace(
                    name: name,
                    symbolName: symbol,
                    accentToken: accent
                ) {
                    selectedID = id
                }
            }
        }
    }

    private var selectedWorkspace: BrowserWorkspace? {
        workspaces.workspaces.first { $0.id == selectedID }
    }

    private func workspaceCard(_ workspace: BrowserWorkspace) -> some View {
        let selected = workspace.id == selectedID
        let color = SettingsPalette.color(workspace.accentName ?? workspace.accentToken)
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                selectedID = workspace.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: workspace.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 34, height: 34)
                        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    if workspace.id == workspaces.selectedWorkspaceID {
                        Text("ACTIVE")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12), in: Capsule())
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        Label("\(workspace.tabIDs.count) tabs", systemImage: "rectangle.stack")
                        if !workspace.pinnedTabIDs.isEmpty {
                            Label("\(workspace.pinnedTabIDs.count) pinned", systemImage: "pin.fill")
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(
                selected ? color.opacity(0.12) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? color.opacity(0.8) : Color.primary.opacity(0.07),
                                  lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func workspaceEditor(_ workspace: BrowserWorkspace) -> some View {
        SettingsCard("Customize \(workspace.name)",
                     subtitle: "Changes are saved immediately and do not move or close any tabs.") {
            VStack(spacing: 0) {
                SettingsValueRow(
                    icon: "textformat",
                    title: "Workspace name",
                    detail: "A short name is easier to scan in the sidebar."
                ) {
                    TextField("Workspace name", text: Binding(
                        get: { workspace.name },
                        set: { workspaces.renameWorkspace(id: workspace.id, name: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                }
                SettingsDivider()
                SettingsValueRow(
                    icon: "house",
                    title: "Home page",
                    detail: "Optional page opened from the Home button in this workspace."
                ) {
                    TextField("https://example.com", text: Binding(
                        get: { workspace.homePage ?? "" },
                        set: { workspaces.setHomePage(id: workspace.id, value: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                }
                SettingsDivider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Icon")
                        .font(.system(size: 12, weight: .semibold))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 10),
                              alignment: .leading, spacing: 8) {
                        ForEach(SettingsPalette.workspaceSymbols, id: \.self) { symbol in
                            Button {
                                workspaces.setSymbol(id: workspace.id, symbol: symbol)
                            } label: {
                                Image(systemName: symbol)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        workspace.symbolName == symbol
                                            ? SettingsPalette.color(workspace.accentName ?? workspace.accentToken).opacity(0.18)
                                            : Color.primary.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9)
                                            .strokeBorder(workspace.symbolName == symbol
                                                ? SettingsPalette.color(workspace.accentName ?? workspace.accentToken)
                                                : Color.primary.opacity(0.06))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                SettingsDivider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Workspace color")
                            .font(.system(size: 13, weight: .medium))
                        Text("Used for selection, icon, and identity throughout the app.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ForEach(SettingsPalette.workspaceTokens, id: \.self) { token in
                        let selected = (workspace.accentName ?? workspace.accentToken) == token
                        Button {
                            workspaces.setAccent(id: workspace.id, value: token)
                        } label: {
                            Circle()
                                .fill(SettingsPalette.color(token))
                                .frame(width: 20, height: 20)
                                .padding(3)
                                .overlay {
                                    Circle().strokeBorder(selected ? Color.primary : .clear, lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .help(token.capitalized)
                    }
                }
                .padding(14)

                if !workspace.isDefault {
                    Divider()
                    HStack {
                        Text("Tabs are moved safely to the current workspace when this workspace is deleted.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Delete Workspace", role: .destructive) {
                            workspaces.deleteWorkspace(id: workspace.id)
                            selectedID = workspaces.workspaces.first?.id
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}

private struct WorkspaceCreator: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "square.grid.2x2"
    @State private var accent = "purple"
    let create: (String, String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SettingsPalette.color(accent))
                    .frame(width: 46, height: 46)
                    .background(SettingsPalette.color(accent).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Workspace").font(.title2.weight(.semibold))
                    Text("Create a focused place for a different activity.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            TextField("Workspace name", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("Choose an icon").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6)) {
                ForEach(SettingsPalette.workspaceSymbols, id: \.self) { item in
                    Button {
                        symbol = item
                    } label: {
                        Image(systemName: item)
                            .frame(width: 36, height: 36)
                            .background(symbol == item ? SettingsPalette.color(accent).opacity(0.2) : .clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Choose a color").font(.headline)
            HStack(spacing: 14) {
                ForEach(SettingsPalette.workspaceTokens, id: \.self) { token in
                    Button { accent = token } label: {
                        Circle().fill(SettingsPalette.color(token)).frame(width: 24, height: 24)
                            .padding(3)
                            .overlay { Circle().strokeBorder(accent == token ? Color.primary : .clear, lineWidth: 2) }
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Create") {
                    create(name, symbol, accent)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(LeafColors.accent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

struct PerformanceSettingsPanel: View {
    @Bindable var settings: SettingsStore
    @Bindable var suspension: TabSuspensionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                SettingsMetricCard(title: "Memory pressure", value: suspension.pressureLevel.title,
                                   icon: "memorychip",
                                   color: suspension.pressureLevel == .normal ? .green : .orange)
                SettingsMetricCard(title: "Active", value: "\(suspension.activeCount)",
                                   icon: "bolt.fill", color: .blue)
                SettingsMetricCard(title: "Sleeping", value: "\(suspension.sleepingCount + suspension.frozenCount)",
                                   icon: "moon.zzz.fill")
                SettingsMetricCard(title: "Discarded", value: "\(suspension.discardedCount)",
                                   icon: "archivebox.fill", color: .orange)
            }

            SettingsCard("Smart Tab Suspension",
                         subtitle: "Reduces memory and energy use by pausing inactive background tabs. Selecting a tab restores it automatically.") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        icon: "gauge.with.dots.needle.67percent",
                        title: "Enable Smart Tab Suspension",
                        detail: "LeafOrLeave evaluates inactive tabs every 10 seconds.",
                        isOn: $settings.value.smartSuspension
                    )
                    SettingsDivider()
                    sliderRow(
                        title: "Suspend after",
                        detail: "A tab must be unused for this long before it is eligible.",
                        value: $settings.value.idleTimeout,
                        range: 300...3600,
                        step: 300,
                        label: "\(Int(settings.value.idleTimeout / 60)) min"
                    )
                    SettingsDivider()
                    sliderRow(
                        title: "Aggressiveness",
                        detail: "Higher values optimize more tabs together and react earlier.",
                        value: $settings.value.suspensionAggressiveness,
                        range: 0.2...1,
                        step: 0.1,
                        label: "\(Int((settings.value.suspensionAggressiveness * 100).rounded()))%"
                    )
                }
                .disabled(!settings.value.smartSuspension)
                .opacity(settings.value.smartSuspension ? 1 : 0.55)
            }

            SettingsCard("Never interrupt",
                         subtitle: "These tabs stay active even when memory pressure increases.") {
                SettingsToggleRow(
                    icon: "play.rectangle.fill",
                    title: "Tabs playing media",
                    detail: "Keeps audio, video, and Picture in Picture running.",
                    isOn: $settings.value.keepMediaAlive
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "pin.fill",
                    title: "Pinned tabs",
                    detail: "Pinned tabs remain immediately available.",
                    isOn: $settings.value.keepPinnedTabsAlive
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "shield.checkered",
                    title: "Exam-protected tabs",
                    detail: "Protected forms and exam pages are never suspended.",
                    isOn: $settings.value.keepExamTabsAlive
                )
            }

            SettingsCard("How it works") {
                VStack(alignment: .leading, spacing: 12) {
                    stateExplanation("Sleeping", "Marks an inactive tab without unloading its page.", "moon.zzz")
                    stateExplanation("Frozen", "Stops work in the page and saves enough state to resume it.", "pause.circle")
                    stateExplanation("Discarded", "Releases the page under critical pressure, then reloads it when selected.", "archivebox")
                    Divider()
                    HStack {
                        if let date = suspension.lastEvaluation {
                            Text("Last evaluated \(date.formatted(date: .omitted, time: .standard)) · \(suspension.lastActionCount) tab(s) optimized")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("No optimization has run yet.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            sync()
                            suspension.optimizeNow()
                        } label: {
                            Label("Optimize Now", systemImage: "wand.and.stars")
                        }
                        .disabled(!settings.value.smartSuspension)
                    }
                }
                .padding(14)
            }
        }
        .onAppear(perform: sync)
        .onChange(of: configuration) { _, _ in sync() }
    }

    private var configuration: PerformanceSettingsConfiguration {
        .init(enabled: settings.value.smartSuspension,
              timeout: settings.value.idleTimeout,
              aggressiveness: settings.value.suspensionAggressiveness,
              media: settings.value.keepMediaAlive,
              pinned: settings.value.keepPinnedTabsAlive,
              exams: settings.value.keepExamTabsAlive)
    }

    private func sync() {
        suspension.apply(settings.value)
    }

    private func sliderRow(
        title: String,
        detail: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: String
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Slider(value: value, in: range, step: step).frame(width: 210)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
        .padding(14)
    }

    private func stateExplanation(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(LeafColors.accent).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PerformanceSettingsConfiguration: Equatable {
    let enabled: Bool
    let timeout: Double
    let aggressiveness: Double
    let media: Bool
    let pinned: Bool
    let exams: Bool
}

struct AppearanceSettingsPanel: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Theme", subtitle: "Choose a foundation, then make the interface yours.") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ForEach(LeafAppearance.allCases, id: \.self) { appearance in
                            themePreview(appearance)
                        }
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Accent color").font(.system(size: 13, weight: .medium))
                            Text("Used for selection, status, and primary actions.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ForEach(UIAccent.allCases, id: \.self) { accent in
                            Button {
                                settings.value.accent = accent
                            } label: {
                                Circle().fill(SettingsPalette.color(accent)).frame(width: 21, height: 21)
                                    .padding(3)
                                    .overlay {
                                        Circle().strokeBorder(settings.value.accent == accent ? Color.primary : .clear,
                                                              lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(accent.rawValue.capitalized)
                        }
                    }
                }
                .padding(14)
            }

            SettingsCard("Interface") {
                SettingsValueRow(icon: "rectangle.compress.vertical", title: "Interface density",
                                 detail: "Controls spacing across tabs, toolbars, and settings.") {
                    Picker("", selection: $settings.value.density) {
                        ForEach(InterfaceDensity.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 285)
                }
                SettingsDivider()
                SettingsValueRow(icon: "sparkles", title: "Animation style",
                                 detail: "Choose how transitions and feedback should feel.") {
                    Picker("", selection: $settings.value.animationStyle) {
                        ForEach(AnimationStyle.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 285)
                }
                SettingsDivider()
                SettingsToggleRow(
                    icon: "circle.lefthalf.filled",
                    title: "Reduce transparency",
                    detail: "Uses more opaque surfaces for stronger contrast.",
                    isOn: $settings.value.reducedTransparency
                )
            }

            SettingsCard("Toolbar", subtitle: "Show only the controls you use.") {
                toggleGrid([
                    ("house", "Home", $settings.value.showHomeButton),
                    ("shield", "Exam Protection", $settings.value.showExamButton),
                    ("arrow.down.circle", "Downloads", $settings.value.showDownloadsButton),
                    ("star", "Bookmarks", $settings.value.showBookmarksButton),
                    ("wifi", "Network latency", $settings.value.showNetworkHUD)
                ])
                .padding(14)
            }

            SettingsCard("New Tab Page", subtitle: "Control the information shown before you start browsing.") {
                SettingsToggleRow(icon: "square.grid.3x2", title: "Quick links",
                                  detail: "Show your customizable website shortcuts.",
                                  isOn: $settings.value.showQuickLinks)
                SettingsDivider()
                SettingsToggleRow(icon: "clock.arrow.circlepath", title: "Recent activity",
                                  detail: "Show recently visited pages for fast return.",
                                  isOn: $settings.value.showRecentActivity)
            }

            SettingsCard("New Tab shortcuts",
                         subtitle: "Edit the label, destination, and icon shown on every New Tab page.") {
                VStack(spacing: 0) {
                    ForEach(settings.value.quickLinks) { link in
                        shortcutEditor(link)
                        if link.id != settings.value.quickLinks.last?.id {
                            SettingsDivider()
                        }
                    }
                    Divider()
                    HStack {
                        Button {
                            settings.addQuickLink()
                        } label: {
                            Label("Add Shortcut", systemImage: "plus")
                        }
                        Spacer()
                        Button("Reset Defaults") { settings.resetQuickLinks() }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func themePreview(_ appearance: LeafAppearance) -> some View {
        let selected = settings.value.appearance == appearance
        let dark = appearance == .dark || appearance == .graphiteDark
        return Button {
            settings.value.appearance = appearance
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(dark ? Color(nsColor: .darkGray) : .white)
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(dark ? .black.opacity(0.35) : .gray.opacity(0.18))
                            .frame(width: 18)
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3).fill(SettingsPalette.color(settings.value.accent)).frame(height: 8)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(dark ? .white.opacity(0.12) : .black.opacity(0.08))
                        }
                    }
                    .padding(9)
                }
                .frame(height: 58)
                Text(themeTitle(appearance))
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? LeafColors.accent.opacity(0.12) : Color.primary.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(selected ? LeafColors.accent : Color.primary.opacity(0.06),
                                  lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func themeTitle(_ appearance: LeafAppearance) -> String {
        switch appearance {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .graphiteDark: "Graphite"
        }
    }

    private func toggleGrid(_ items: [(String, String, Binding<Bool>)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Image(systemName: item.0).foregroundStyle(LeafColors.accent).frame(width: 20)
                    Text(item.1).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: item.2).labelsHidden()
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func shortcutEditor(_ link: QuickLink) -> some View {
        HStack(spacing: 12) {
            Picker("", selection: quickLinkBinding(link.id, \.symbol)) {
                ForEach(SettingsPalette.workspaceSymbols + ["sparkles"], id: \.self) {
                    Image(systemName: $0).tag($0)
                }
            }
            .labelsHidden()
            .frame(width: 54)
            VStack(spacing: 7) {
                TextField("Shortcut name", text: quickLinkBinding(link.id, \.title))
                    .textFieldStyle(.roundedBorder)
                TextField("https://example.com", text: quickLinkBinding(link.id, \.url))
                    .textFieldStyle(.roundedBorder)
            }
            Button(role: .destructive) {
                settings.removeQuickLink(link.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove shortcut")
        }
        .padding(14)
    }

    private func quickLinkBinding(_ id: UUID, _ keyPath: WritableKeyPath<QuickLink, String>) -> Binding<String> {
        Binding {
            settings.value.quickLinks.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
        } set: { newValue in
            guard let index = settings.value.quickLinks.firstIndex(where: { $0.id == id }) else { return }
            settings.value.quickLinks[index][keyPath: keyPath] = newValue
        }
    }
}

struct DeveloperSettingsPanel: View {
    @Bindable var settings: SettingsStore
    let tabs: TabManager
    @State private var showsConsole = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Developer Mode",
                         subtitle: "Developer features can expose page internals. Enable them only on content you trust.") {
                SettingsToggleRow(icon: "hammer.fill", title: "Enable developer features",
                                  detail: "Unlock page inspection, console capture, and debugging actions.",
                                  isOn: $settings.value.developerMode)
                SettingsDivider()
                SettingsToggleRow(icon: "safari", title: "Allow Web Inspector",
                                  detail: "Marks browser pages as inspectable by WebKit developer tools.",
                                  isOn: $settings.value.webInspector,
                                  enabled: settings.value.developerMode)
                SettingsDivider()
                SettingsToggleRow(icon: "text.alignleft", title: "Capture console messages",
                                  detail: "Keeps up to 500 log, warning, and error messages per tab.",
                                  isOn: $settings.value.captureConsoleLogs,
                                  enabled: settings.value.developerMode)
                SettingsDivider()
                SettingsToggleRow(icon: "terminal", title: "Show Terminal shortcut",
                                  detail: "Adds quick access to Terminal from developer surfaces.",
                                  isOn: $settings.value.showTerminalShortcut,
                                  enabled: settings.value.developerMode)
            }

            SettingsCard("Active page", subtitle: activePageSubtitle) {
                HStack(spacing: 10) {
                    SettingsMetricCard(title: "Console entries",
                                       value: "\(tabs.selectedTab?.consoleMessages.count ?? 0)",
                                       icon: "text.alignleft", color: .blue)
                    SettingsMetricCard(title: "Page zoom",
                                       value: "\(Int(((tabs.selectedTab?.webView.pageZoom ?? 1) * 100).rounded()))%",
                                       icon: "plus.magnifyingglass")
                    SettingsMetricCard(title: "Inspectable",
                                       value: tabs.selectedTab?.webView.isInspectable == true ? "Yes" : "No",
                                       icon: "ladybug", color: .orange)
                }
                .padding(14)
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                    actionButton("Open Developer Console", "terminal.fill") { showsConsole = true }
                    actionButton("Enable Page Inspection", "ladybug.fill") {
                        tabs.selectedTab?.webView.isInspectable = true
                    }
                    actionButton("Hard Reload", "arrow.clockwise") {
                        tabs.selectedTab?.webView.reloadFromOrigin()
                    }
                    actionButton("Clear Console", "trash") {
                        tabs.selectedTab?.consoleMessages.removeAll()
                    }
                    actionButton("Copy Page URL", "link") {
                        copy(tabs.selectedTab?.url?.absoluteString ?? "")
                    }
                    actionButton("Copy User Agent", "doc.on.doc") {
                        tabs.selectedTab?.webView.evaluateJavaScript("navigator.userAgent") { value, _ in
                            if let value = value as? String { copy(value) }
                        }
                    }
                }
                .padding(14)
                .disabled(!settings.value.developerMode || tabs.selectedTab == nil)
            }

            SettingsCard("System tools") {
                SettingsValueRow(icon: "terminal", title: "Terminal",
                                 detail: "Open the macOS Terminal application.") {
                    Button("Open Terminal", action: openTerminal)
                        .disabled(!settings.value.developerMode)
                }
            }
        }
        .onChange(of: settings.value.webInspector) { _, enabled in
            if enabled {
                tabs.tabs.forEach { $0.webView.isInspectable = true }
            }
        }
        .sheet(isPresented: $showsConsole) {
            DeveloperConsoleView(tab: tabs.selectedTab)
        }
    }

    private var activePageSubtitle: String {
        guard let tab = tabs.selectedTab else { return "No page is currently selected." }
        return "\(tab.title) · \(tab.url?.host ?? "New Tab")"
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    private func openTerminal() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func copy(_ value: String) {
        LeafClipboard.copy(value)
    }
}

struct AdvancedSettingsPanel: View {
    @Bindable var settings: SettingsStore
    let tabs: TabManager
    let downloads: DownloadManager
    let workspaces: WorkspaceManager
    let network: NetworkMonitor
    @Bindable var passwordVault: PasswordVault
    let clearWebsiteData: () -> Void
    let resetSettings: () -> Void
    let copyDiagnostics: () -> Void

    @State private var websiteRecordCount = 0
    @State private var showsCredentialEditor = false
    @State private var editingCredential: PasswordCredential?
    @State private var errorMessage: String?
    @State private var revealedCredentialIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Passwords & Autofill",
                         subtitle: "Passwords are stored in the macOS Keychain and never in LeafOrLeave settings or diagnostics.") {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: passwordVault.isUnlocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(passwordVault.isUnlocked ? .green : LeafColors.accent)
                            .frame(width: 38, height: 38)
                            .background((passwordVault.isUnlocked ? Color.green : LeafColors.accent).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(passwordVault.isUnlocked ? "Password Vault unlocked" : "Password Vault locked")
                                .font(.system(size: 14, weight: .semibold))
                            Text(passwordVault.isUnlocked
                                 ? "\(passwordVault.credentials.count) credential(s) available until the vault auto-locks."
                                 : "\(passwordVault.storedCredentialCount) credential(s) protected by Touch ID or your Mac login password.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if passwordVault.isUnlocked {
                            Button("Lock Now") { passwordVault.lock() }
                        } else {
                            Button {
                                Task {
                                    _ = await passwordVault.unlock(
                                        reason: "View and manage saved passwords in LeafOrLeave.",
                                        autoLockMinutes: settings.value.passwordAutoLockMinutes
                                    )
                                }
                            } label: {
                                Label("Unlock", systemImage: "touchid")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LeafColors.accent)
                        }
                    }
                    .padding(14)
                    SettingsDivider()
                    SettingsToggleRow(icon: "rectangle.and.pencil.and.ellipsis",
                                      title: "Autofill passwords",
                                      detail: "Authenticate, then fill matching sign-in forms for the current website.",
                                      isOn: $settings.value.autoFillPasswords)
                    SettingsDivider()
                    SettingsToggleRow(icon: "key.fill",
                                      title: "Offer to save passwords",
                                      detail: "Ask before saving a submitted sign-in to the macOS Keychain.",
                                      isOn: $settings.value.offerToSavePasswords)
                    SettingsDivider()
                    SettingsValueRow(icon: "timer", title: "Lock vault after",
                                     detail: "Credentials are removed from app memory when the vault locks.") {
                        Picker("", selection: $settings.value.passwordAutoLockMinutes) {
                            Text("1 minute").tag(1.0)
                            Text("5 minutes").tag(5.0)
                            Text("15 minutes").tag(15.0)
                            Text("30 minutes").tag(30.0)
                        }
                        .labelsHidden().frame(width: 140)
                    }
                }
            }

            if passwordVault.isUnlocked {
                SettingsCard("Saved passwords",
                             subtitle: "Reveal, copy, or edit a password while the authenticated vault is unlocked.") {
                    VStack(spacing: 0) {
                        if passwordVault.credentials.isEmpty {
                            ContentUnavailableView(
                                "No Saved Passwords",
                                systemImage: "key",
                                description: Text("LeafOrLeave can offer to save a password the next time you sign in.")
                            )
                            .frame(minHeight: 145)
                        } else {
                            ForEach(passwordVault.credentials) { credential in
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .foregroundStyle(LeafColors.accent)
                                        .frame(width: 30, height: 30)
                                        .background(Color.primary.opacity(0.05),
                                                    in: RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(credential.host).font(.system(size: 13, weight: .semibold))
                                        Text(credential.username).font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(revealedCredentialIDs.contains(credential.id)
                                         ? credential.password
                                         : "••••••••")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(revealedCredentialIDs.contains(credential.id)
                                                         ? .primary : .secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 180, alignment: .trailing)
                                        .privacySensitive()
                                    Button {
                                        if revealedCredentialIDs.contains(credential.id) {
                                            revealedCredentialIDs.remove(credential.id)
                                        } else {
                                            revealedCredentialIDs.insert(credential.id)
                                        }
                                    } label: {
                                        Image(systemName: revealedCredentialIDs.contains(credential.id)
                                              ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(revealedCredentialIDs.contains(credential.id)
                                          ? "Hide password" : "Reveal password")
                                    Button {
                                        LeafClipboard.copy(
                                            credential.password,
                                            clearAfter: 60
                                        )
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Copy password")
                                    Button("Edit") {
                                        editingCredential = credential
                                        showsCredentialEditor = true
                                    }
                                    Button(role: .destructive) {
                                        do { try passwordVault.delete(credential) }
                                        catch { errorMessage = error.localizedDescription }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(14)
                                if credential.id != passwordVault.credentials.last?.id {
                                    SettingsDivider()
                                }
                            }
                        }
                        Divider()
                        HStack {
                            Button {
                                editingCredential = nil
                                showsCredentialEditor = true
                            } label: {
                                Label("Add Manually", systemImage: "plus")
                            }
                            .help("Optional fallback—LeafOrLeave offers to save passwords automatically when you sign in.")
                            Spacer()
                            Label("Touch ID / Mac password protected", systemImage: "touchid")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                }
            }

            SettingsCard("Website sessions",
                         subtitle: "LeafOrLeave uses WebKit’s persistent website data store, so Google and other website logins survive app restarts.") {
                SettingsValueRow(icon: "person.crop.circle.badge.checkmark",
                                 title: "Keep website logins",
                                 detail: "Cookies and authentication sessions remain on this Mac until you clear website data.") {
                    Text("ON")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: Capsule())
                }
                SettingsDivider()
                SettingsValueRow(icon: "externaldrive", title: "Stored website records",
                                 detail: "Includes cookies, cache, local storage, and other WebKit website data.") {
                    Text("\(websiteRecordCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                SettingsDivider()
                HStack {
                    Text("Clearing this data signs you out of websites but does not delete saved Keychain passwords.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Website Data…", role: .destructive, action: clearWebsiteData)
                }
                .padding(14)
            }

            SettingsCard("Diagnostics") {
                SettingsToggleRow(icon: "waveform.path.ecg", title: "Diagnostics metrics",
                                  detail: "Collect local operational counters without URLs, form contents, or credentials.",
                                  isOn: $settings.value.diagnosticsMetrics)
                SettingsDivider()
                HStack(spacing: 10) {
                    SettingsMetricCard(title: "Open tabs", value: "\(tabs.tabs.count)", icon: "rectangle.stack")
                    SettingsMetricCard(title: "Workspaces", value: "\(workspaces.workspaces.count)", icon: "square.grid.2x2")
                    SettingsMetricCard(title: "Connection", value: network.quality.title, icon: "wifi", color: .green)
                }
                .padding(14)
                Divider()
                HStack {
                    Label("Reports exclude URLs, cookies, passwords, form contents, and authentication tokens.",
                          systemImage: "lock.shield")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy Diagnostics Report", action: copyDiagnostics)
                }
                .padding(14)
            }

            SettingsCard("Maintenance") {
                SettingsValueRow(icon: "folder", title: "Downloads folder",
                                 detail: "Open the destination used for downloaded files.") {
                    Button("Open Folder") {
                        NSWorkspace.shared.open(
                            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                        )
                    }
                }
                SettingsDivider()
                SettingsValueRow(icon: "arrow.counterclockwise", title: "Reset settings",
                                 detail: "Restores appearance, toolbar, network, performance, and New Tab defaults.") {
                    Button("Reset LeafOrLeave…", role: .destructive, action: resetSettings)
                }
            }
        }
        .task { refreshWebsiteDataCount() }
        .onChange(of: passwordVault.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                revealedCredentialIDs.removeAll()
                editingCredential = nil
                showsCredentialEditor = false
            }
        }
        .onChange(of: settings.value.diagnosticsMetrics) { _, enabled in
            LeafLogStore.shared.setCollectionEnabled(enabled)
        }
        .sheet(isPresented: $showsCredentialEditor) {
            CredentialEditor(credential: editingCredential) { host, username, password, id in
                do {
                    try passwordVault.save(host: host, username: username, password: password, id: id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Password Vault", isPresented: Binding(
            get: { errorMessage != nil || passwordVault.lastError != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                    passwordVault.clearError()
                }
            }
        )) {
            Button("OK") {
                errorMessage = nil
                passwordVault.clearError()
            }
        } message: {
            Text(errorMessage ?? passwordVault.lastError ?? "Unknown error")
        }
    }

    private func refreshWebsiteDataCount() {
        WKWebsiteDataStore.default().fetchDataRecords(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
        ) { records in
            Task { @MainActor in websiteRecordCount = records.count }
        }
    }
}

private struct CredentialEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var host: String
    @State private var username: String
    @State private var password: String
    @State private var revealsPassword = false
    private let id: UUID?
    let save: (String, String, String, UUID?) -> Void

    init(credential: PasswordCredential?,
         save: @escaping (String, String, String, UUID?) -> Void) {
        _host = State(initialValue: credential?.host ?? "")
        _username = State(initialValue: credential?.username ?? "")
        _password = State(initialValue: credential?.password ?? "")
        id = credential?.id
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LeafColors.accent)
                    .frame(width: 42, height: 42)
                    .background(LeafColors.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(id == nil ? "Add Password" : "Update Password")
                        .font(.title2.weight(.semibold))
                    Text("Stored securely in the macOS Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Website").font(.caption.weight(.semibold))
                TextField("accounts.example.com", text: $host).textFieldStyle(.roundedBorder)
                Text("Username or email").font(.caption.weight(.semibold))
                TextField("captain@example.com", text: $username).textFieldStyle(.roundedBorder)
                Text("Password").font(.caption.weight(.semibold))
                HStack(spacing: 8) {
                    Group {
                        if revealsPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Button {
                        revealsPassword.toggle()
                    } label: {
                        Image(systemName: revealsPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(revealsPassword ? "Hide password" : "Reveal password")
                }
            }
            Label("The password is available only while this authenticated vault is unlocked and is removed from app memory when it locks.",
                  systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    save(host, username, password, id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(LeafColors.accent)
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty ||
                          username.trimmingCharacters(in: .whitespaces).isEmpty ||
                          password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
