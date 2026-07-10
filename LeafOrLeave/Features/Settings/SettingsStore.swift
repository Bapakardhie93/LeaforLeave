import Foundation
import Observation

enum SettingsSection: String, CaseIterable, Identifiable { case general, tabs, workspaces, performance, network, examProtection, media, privacy, appearance, advanced; var id: String { rawValue }; var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() } }
enum LeafAppearance: String, Codable, CaseIterable { case system, light, dark, graphiteDark }
enum SearchEngine: String, Codable, CaseIterable { case google, duckDuckGo, bing, custom }

struct SettingsData: Codable {
    var searchEngine = SearchEngine.google; var customSearchTemplate = "https://example.com/search?q={query}"; var reopenSession = true; var askDownloadDestination = false
    var showFavicons = true; var showMediaIndicators = true; var compactTabs = false; var showSidebar = true
    var smartSuspension = true; var idleTimeout = 900.0; var autoPiP = false; var keepMediaAlive = true
    var connectivityWarnings = true; var offlineOverlay = true; var suggestExamProtection = true
    var appearance = LeafAppearance.graphiteDark; var reducedTransparency = false; var diagnosticsMetrics = true; var onboardingCompleted = false
}

@MainActor @Observable
final class SettingsStore {
    var value: SettingsData { didSet { save() } }
    private let defaults: UserDefaults; private let key = "settings.typed.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; value = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SettingsData.self, from: $0) } ?? SettingsData() }
    func validCustomSearchTemplate() -> Bool { value.customSearchTemplate.contains("{query}") && URL(string: value.customSearchTemplate.replacingOccurrences(of: "{query}", with: "test")) != nil }
    func resetMedia() { value.autoPiP = false; value.keepMediaAlive = true }
    private func save() { if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) } }
}
