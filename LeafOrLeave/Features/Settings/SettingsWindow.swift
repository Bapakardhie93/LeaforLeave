import AppKit
import SwiftUI
import WebKit

struct SettingsWindow: View {
    @Bindable var settings: SettingsStore
    let tabs: TabManager
    let downloads: DownloadManager
    let exams: ExamProtectionManager
    let workspaces: WorkspaceManager
    let network: NetworkMonitor
    let suspension: TabSuspensionManager
    let passwordVault: PasswordVault

    @State private var section = SettingsSection.general
    @State private var confirmWebsiteData = false
    @State private var confirmSettingsReset = false
    @State private var settingsSearch = ""

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: 238)
            Rectangle().fill(.white.opacity(0.07)).frame(width: 1)
            settingsDetail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 960, idealWidth: 1120, minHeight: 680, idealHeight: 800)
        .alert("Clear all website data?", isPresented: $confirmWebsiteData) {
            Button("Cancel", role: .cancel) {}
            Button("Clear and Log Out", role: .destructive) {
                WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: .distantPast
                ) {}
            }
        } message: {
            Text("This clears cookies, cache, and local storage, and signs you out of websites. Passwords saved in the macOS Keychain are not deleted.")
        }
        .alert("Reset all LeafOrLeave settings?", isPresented: $confirmSettingsReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Settings", role: .destructive) {
                settings.resetToDefaults()
                suspension.apply(settings.value)
            }
        } message: {
            Text("Appearance, toolbar, performance, network preferences, and New Tab shortcuts return to their defaults. Workspaces and saved passwords are not deleted.")
        }
    }

    private var settingsSidebar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(LeafColors.accent)
                    .frame(width: 30, height: 30)
                    .background(LeafColors.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings").font(.headline)
                    Text("LeafOrLeave").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search settings", text: $settingsSearch)
                    .textFieldStyle(.plain)
                if !settingsSearch.isEmpty {
                    Button { settingsSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.06)) }
            .padding(.horizontal, 12)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(filteredSections) { item in
                        settingsSidebarRow(item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .background(.black.opacity(0.13))
    }

    private var settingsDetail: some View {
        ZStack {
            LinearGradient(
                colors: [LeafColors.accent.opacity(0.045), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 11) {
                    Image(systemName: icon(section))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LeafColors.accent)
                        .frame(width: 40, height: 40)
                        .background(LeafColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .font(LeafTypography.navigationTitle)
                        Text(sectionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 840, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.top, 28)
                .padding(.bottom, 20)

                ScrollView {
                    detailContent
                        .frame(maxWidth: 840, alignment: .leading)
                        .padding(.horizontal, 34)
                        .padding(.bottom, 34)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section {
        case .general:
            generalPanel
        case .tabs:
            tabsPanel
        case .workspaces:
            WorkspaceSettingsPanel(workspaces: workspaces)
        case .performance:
            PerformanceSettingsPanel(settings: settings, suspension: suspension)
        case .network:
            networkPanel
        case .examProtection:
            examPanel
        case .media:
            mediaPanel
        case .privacy:
            privacyPanel
        case .appearance:
            AppearanceSettingsPanel(settings: settings)
        case .developer:
            DeveloperSettingsPanel(settings: settings, tabs: tabs)
        case .advanced:
            AdvancedSettingsPanel(
                settings: settings,
                tabs: tabs,
                downloads: downloads,
                workspaces: workspaces,
                network: network,
                passwordVault: passwordVault,
                clearWebsiteData: { confirmWebsiteData = true },
                resetSettings: { confirmSettingsReset = true },
                copyDiagnostics: copyDiagnostics
            )
        }
    }

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Search", subtitle: "Choose the engine used for address-bar searches.") {
                SettingsValueRow(icon: "magnifyingglass", title: "Search engine") {
                    Picker("", selection: $settings.value.searchEngine) {
                        ForEach(SearchEngine.allCases, id: \.self) {
                            Text(searchEngineName($0)).tag($0)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                if settings.value.searchEngine == .custom {
                    SettingsDivider()
                    VStack(alignment: .leading, spacing: 7) {
                        TextField("Custom URL containing {query}",
                                  text: $settings.value.customSearchTemplate)
                            .textFieldStyle(.roundedBorder)
                        if !settings.validCustomSearchTemplate() {
                            Label("The URL must be valid and contain {query}.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(14)
                }
            }

            SettingsCard("Startup & Downloads") {
                SettingsToggleRow(
                    icon: "arrow.counterclockwise.circle",
                    title: "Reopen previous session",
                    detail: "Restore tabs and each workspace’s selected tab when LeafOrLeave starts.",
                    isOn: $settings.value.reopenSession
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "folder.badge.questionmark",
                    title: "Ask where to save downloads",
                    detail: "Choose a destination before each download begins.",
                    isOn: $settings.value.askDownloadDestination
                )
            }
        }
    }

    private var tabsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Tab bar", subtitle: "Keep tabs readable without hiding useful status.") {
                SettingsToggleRow(
                    icon: "app.dashed",
                    title: "Show favicons",
                    detail: "Display each website’s icon beside its title.",
                    isOn: $settings.value.showFavicons
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "speaker.wave.2.fill",
                    title: "Show media indicators",
                    detail: "Identify tabs playing audio, video, or Picture in Picture.",
                    isOn: $settings.value.showMediaIndicators
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "rectangle.compress.vertical",
                    title: "Compact tabs",
                    detail: "Reduce tab height while preserving the close button and title spacing.",
                    isOn: $settings.value.compactTabs
                )
            }
            SettingsCard("Workspace behavior") {
                SettingsToggleRow(
                    icon: "sidebar.left",
                    title: "Show workspace sidebar",
                    detail: "Keep workspace switching and Library controls visible.",
                    isOn: $settings.value.showSidebar
                )
            }
        }
    }

    private var networkPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                SettingsMetricCard(
                    title: "Status",
                    value: network.isConnected ? "Online" : "Offline",
                    icon: network.isConnected ? "wifi" : "wifi.slash",
                    color: network.isConnected ? .green : .red
                )
                SettingsMetricCard(
                    title: "Latency",
                    value: network.latencyMS.map { "\($0) ms" } ?? "Measuring…",
                    icon: "speedometer",
                    color: .blue
                )
                SettingsMetricCard(
                    title: "Quality",
                    value: network.quality.title,
                    icon: "chart.bar.fill"
                )
            }

            SettingsCard("Connection feedback") {
                SettingsToggleRow(icon: "wifi", title: "Toolbar network indicator",
                                  detail: "Show current latency in the browser toolbar.",
                                  isOn: $settings.value.showNetworkHUD)
                SettingsDivider()
                SettingsToggleRow(icon: "exclamationmark.bubble", title: "Connectivity warnings",
                                  detail: "Warn when the connection becomes unreliable.",
                                  isOn: $settings.value.connectivityWarnings)
                SettingsDivider()
                SettingsToggleRow(icon: "wifi.slash", title: "Offline overlay",
                                  detail: "Explain connection loss without replacing page state.",
                                  isOn: $settings.value.offlineOverlay)
                Divider()
                HStack {
                    Text("Latency is measured without changing your macOS network configuration.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Measure Again") { network.refreshLatency() }
                }
                .padding(14)
            }

            SettingsCard("DNS & VPN",
                         subtitle: "WebKit follows macOS routing. LeafOrLeave never installs a DNS profile or VPN tunnel silently.") {
                SettingsValueRow(icon: "lock.shield", title: "Privacy mode") {
                    Picker("", selection: $settings.value.networkPrivacyMode) {
                        Text("Use macOS Settings").tag(NetworkPrivacyMode.system)
                        Text("Private DNS").tag(NetworkPrivacyMode.privateDNS)
                        Text("VPN").tag(NetworkPrivacyMode.vpn)
                    }
                    .labelsHidden().frame(width: 190)
                }
                SettingsDivider()
                SettingsValueRow(icon: "server.rack", title: "Preferred DNS") {
                    Picker("", selection: $settings.value.dnsProvider) {
                        ForEach([
                            "System Default",
                            "Cloudflare (1.1.1.1)",
                            "Google (8.8.8.8)",
                            "Quad9 (9.9.9.9)"
                        ], id: \.self) { Text($0) }
                    }
                    .labelsHidden().frame(width: 210)
                }
                Divider()
                HStack {
                    Spacer()
                    Button(settings.value.networkPrivacyMode == .vpn
                           ? "Open VPN Settings"
                           : "Open Network Settings") {
                        RecoveryAssistant.openNetworkSettings()
                    }
                }
                .padding(14)
            }
        }
    }

    private var examPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                SettingsMetricCard(
                    title: "Protected tabs",
                    value: "\(tabs.tabs.filter(\.isExamProtected).count)",
                    icon: "shield.checkered",
                    color: .green
                )
                SettingsMetricCard(
                    title: "Open tabs",
                    value: "\(tabs.tabs.count)",
                    icon: "rectangle.stack",
                    color: .blue
                )
            }
            SettingsCard("Protection") {
                SettingsToggleRow(
                    icon: "checkmark.shield",
                    title: "Suggest protection on quiz pages",
                    detail: "Offer protection when LeafOrLeave recognizes an important form or assessment.",
                    isOn: $settings.value.suggestExamProtection
                )
                Divider()
                HStack {
                    Text("Recovery data contains only the state required to restore protected work.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Recovery Data", role: .destructive) { exams.clear() }
                }
                .padding(14)
            }
        }
    }

    private var mediaPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Playback") {
                SettingsToggleRow(
                    icon: "pip.enter",
                    title: "Automatically enter Picture in Picture",
                    detail: "Keep eligible video visible when you move away from its tab.",
                    isOn: $settings.value.autoPiP
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "play.rectangle.on.rectangle",
                    title: "Keep media tabs active",
                    detail: "Smart Tab Suspension will not pause tabs playing audio or video.",
                    isOn: $settings.value.keepMediaAlive
                )
                Divider()
                HStack {
                    Spacer()
                    Button("Reset Media Settings") {
                        settings.resetMedia()
                        suspension.apply(settings.value)
                    }
                }
                .padding(14)
            }
        }
    }

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Website data",
                         subtitle: "Cookies keep website logins active across restarts. Clear them only when you want to sign out everywhere.") {
                SettingsValueRow(icon: "externaldrive", title: "Persistent sessions",
                                 detail: "Stored locally by WebKit using the default persistent data store.") {
                    Text("Enabled")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                SettingsDivider()
                SettingsValueRow(icon: "trash", title: "Clear website data",
                                 detail: "Removes cookies, cache, and website storage, then signs you out.") {
                    Button("Clear…", role: .destructive) { confirmWebsiteData = true }
                }
            }
            SettingsCard("System privacy") {
                SettingsValueRow(icon: "hand.raised", title: "macOS permissions",
                                 detail: "Review camera, microphone, and other sensitive permissions.") {
                    Button("Open Privacy Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                SettingsDivider()
                SettingsValueRow(icon: "arrow.down.circle", title: "Download history",
                                 detail: "Clears completed items from LeafOrLeave, not the downloaded files.") {
                    Button("Clear History") { downloads.clearCompleted() }
                }
            }
        }
    }

    private func settingsSidebarRow(_ item: SettingsSection) -> some View {
        let selected = section == item
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { section = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon(item)).frame(width: 21)
                Text(item.title).fontWeight(selected ? .semibold : .regular)
                Spacer()
                if selected {
                    Image(systemName: "chevron.right").font(.caption2).opacity(0.75)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 39)
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.88))
            .background(
                selected ? LeafColors.accent.opacity(0.82) : Color.white.opacity(0.001),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(item.title)
    }

    private var filteredSections: [SettingsSection] {
        guard !settingsSearch.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(settingsSearch) ||
            description(for: $0).localizedCaseInsensitiveContains(settingsSearch)
        }
    }

    private var sectionDescription: String {
        description(for: section)
    }

    private func description(for section: SettingsSection) -> String {
        switch section {
        case .general: "Search, startup, and download behavior."
        case .tabs: "Make every tab readable, predictable, and easy to control."
        case .workspaces: "Build focused browsing spaces for every activity."
        case .performance: "Balance responsiveness, memory use, and battery life."
        case .network: "Understand connection quality and macOS network privacy."
        case .examProtection: "Protect important forms and assessment work."
        case .media: "Control playback, Picture in Picture, and background media."
        case .privacy: "Manage website data and sensitive macOS permissions."
        case .appearance: "Personalize theme, spacing, toolbar, and New Tab."
        case .developer: "Inspect pages, capture console output, and debug safely."
        case .advanced: "Passwords, persistent sessions, diagnostics, and maintenance."
        }
    }

    private func icon(_ section: SettingsSection) -> String {
        switch section {
        case .general: "gearshape"
        case .tabs: "rectangle.on.rectangle"
        case .workspaces: "square.grid.2x2"
        case .performance: "gauge.with.dots.needle.67percent"
        case .network: "wifi"
        case .examProtection: "shield"
        case .media: "play.circle"
        case .privacy: "hand.raised"
        case .appearance: "paintbrush"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .advanced: "wrench.and.screwdriver"
        }
    }

    private func searchEngineName(_ engine: SearchEngine) -> String {
        switch engine {
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        case .bing: "Bing"
        case .custom: "Custom"
        }
    }

    private func copyDiagnostics() {
        let report = DiagnosticsService().report(
            tabs: tabs,
            network: network,
            workspace: workspaces
        )
        LeafClipboard.copy(report)
        LeafLog.info("Diagnostics report copied", category: .app)
    }
}
