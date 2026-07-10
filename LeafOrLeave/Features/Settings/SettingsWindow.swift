import SwiftUI
import WebKit

struct SettingsWindow: View {
    @Bindable var settings: SettingsStore
    let tabs: TabManager; let downloads: DownloadManager; let exams: ExamProtectionManager
    @State private var section = SettingsSection.general
    @State private var confirmWebsiteData = false
    var body: some View {
        NavigationSplitView { List(SettingsSection.allCases, selection: $section) { item in Label(item.title, systemImage: icon(item)).tag(item) }.navigationTitle("Settings") } detail: { Form { content }.formStyle(.grouped).navigationTitle(section.title) }
            .frame(width: 760, height: 540).alert("Clear all website data?", isPresented: $confirmWebsiteData) { Button("Cancel", role: .cancel) {}; Button("Clear and Log Out", role: .destructive) { WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {} } } message: { Text("This clears cookies and cache and signs you out of websites.") }
    }
    @ViewBuilder private var content: some View {
        switch section {
        case .general: Picker("Search engine", selection: $settings.value.searchEngine) { ForEach(SearchEngine.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; Toggle("Reopen previous session", isOn: $settings.value.reopenSession); Toggle("Ask where to save downloads", isOn: $settings.value.askDownloadDestination)
        case .tabs: Toggle("Show favicons", isOn: $settings.value.showFavicons); Toggle("Show media indicators", isOn: $settings.value.showMediaIndicators); Toggle("Compact tabs", isOn: $settings.value.compactTabs)
        case .workspaces: Text("Workspace names, order, and tab membership are stored locally.")
        case .performance: Toggle("Smart Tab Suspension", isOn: $settings.value.smartSuspension); Slider(value: $settings.value.idleTimeout, in: 300...1800, step: 300); Toggle("Keep media tabs active", isOn: $settings.value.keepMediaAlive)
        case .network: Toggle("Connectivity warnings", isOn: $settings.value.connectivityWarnings); Toggle("Show offline overlay", isOn: $settings.value.offlineOverlay); Button("Open Network Settings", action: RecoveryAssistant.openNetworkSettings)
        case .examProtection: Toggle("Suggest protection on quiz pages", isOn: $settings.value.suggestExamProtection); Text("Protected tabs: \(tabs.tabs.filter(\.isExamProtected).count)"); Button("Clear recovery data", role: .destructive) { exams.clear() }
        case .media: Toggle("Automatically enter PiP", isOn: $settings.value.autoPiP); Toggle("Keep media tabs active", isOn: $settings.value.keepMediaAlive); Button("Reset media settings") { settings.resetMedia() }
        case .privacy: Button("Clear Website Data…", role: .destructive) { confirmWebsiteData = true }; Button("Clear Download History") { downloads.clearCompleted() }; Text("Private browsing is planned for a future sprint.").foregroundStyle(.secondary)
        case .appearance: Picker("Appearance", selection: $settings.value.appearance) { ForEach(LeafAppearance.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; Toggle("Reduce transparency", isOn: $settings.value.reducedTransparency)
        case .advanced: Toggle("Diagnostics metrics", isOn: $settings.value.diagnosticsMetrics); Text("Diagnostics never includes URLs, cookies, passwords, form contents, or tokens.")
        }
    }
    private func icon(_ s: SettingsSection) -> String { ["general":"gear","tabs":"rectangle.on.rectangle","workspaces":"square.grid.2x2","performance":"gauge","network":"wifi","examProtection":"shield","media":"play.circle","privacy":"hand.raised","appearance":"paintbrush","advanced":"wrench"].first { $0.key == s.rawValue }?.value ?? "gear" }
}
