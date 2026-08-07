import Foundation
import Observation
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, tabs, workspaces, performance, network, examProtection, media, privacy, appearance, developer, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .examProtection: "Exam Protection"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}
enum LeafAppearance: String, Codable, CaseIterable { case system, light, dark, graphiteDark, liquidGlass }
enum SearchEngine: String, Codable, CaseIterable { case google, duckDuckGo, bing, custom }
enum UIAccent: String, Codable, CaseIterable { case violet, blue, teal, green, orange, pink }
enum InterfaceDensity: String, Codable, CaseIterable { case comfortable, compact, spacious }
enum AnimationStyle: String, Codable, CaseIterable { case system, gentle, playful, none }
enum BrowserToolbarStyle: String, Codable, CaseIterable { case unified, minimal, floating }
enum ToolbarIconScale: String, Codable, CaseIterable { case small, regular, large }
enum TabPlacement: String, Codable, CaseIterable { case top, left }
enum NewTabBackgroundStyle: String, Codable, CaseIterable { case ambient, gradient, solid }
enum NetworkPrivacyMode: String, Codable, CaseIterable { case system, privateDNS, vpn }

enum BrowserShortcutAction: String, Codable, CaseIterable, Identifiable {
    case newWindow, newTab, newPrivateTab, reopenClosedTab, closeTab
    case back, forward, reload, focusAddress, findInPage, toggleSidebar, searchTabs, addSplit

    var id: String { rawValue }
    var title: String {
        switch self {
        case .newWindow: "New Window"
        case .newTab: "New Tab"
        case .newPrivateTab: "New Private Tab"
        case .reopenClosedTab: "Reopen Closed Tab"
        case .closeTab: "Close Tab"
        case .back: "Back"
        case .forward: "Forward"
        case .reload: "Reload"
        case .focusAddress: "Focus Address Bar"
        case .findInPage: "Find in Page"
        case .toggleSidebar: "Show or Hide Sidebar"
        case .searchTabs: "Search Tabs"
        case .addSplit: "Add Split Panel"
        }
    }
    var symbol: String {
        switch self {
        case .newWindow: "macwindow.badge.plus"
        case .newTab: "plus.square"
        case .newPrivateTab: "eye.slash.fill"
        case .reopenClosedTab: "arrow.uturn.backward"
        case .closeTab: "xmark.square"
        case .back: "chevron.left"
        case .forward: "chevron.right"
        case .reload: "arrow.clockwise"
        case .focusAddress: "text.cursor"
        case .findInPage: "text.magnifyingglass"
        case .toggleSidebar: "sidebar.left"
        case .searchTabs: "rectangle.stack"
        case .addSplit: "rectangle.split.2x1"
        }
    }
}

struct BrowserShortcutModifiers: OptionSet, Codable, Hashable {
    let rawValue: Int
    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        if contains(.command) { result.insert(.command) }
        if contains(.shift) { result.insert(.shift) }
        if contains(.option) { result.insert(.option) }
        if contains(.control) { result.insert(.control) }
        return result
    }

    var display: String {
        var value = ""
        if contains(.control) { value += "⌃" }
        if contains(.option) { value += "⌥" }
        if contains(.shift) { value += "⇧" }
        if contains(.command) { value += "⌘" }
        return value
    }
}

struct BrowserShortcut: Codable, Equatable, Hashable {
    var key: String
    var modifiers: BrowserShortcutModifiers

    var keyEquivalent: KeyEquivalent {
        switch key {
        case "tab": .tab
        case "left": .leftArrow
        case "right": .rightArrow
        case "up": .upArrow
        case "down": .downArrow
        case "escape": .escape
        case "return": .return
        case "space": .space
        case "delete": .delete
        default: KeyEquivalent(key.first ?? "?")
        }
    }

    var display: String {
        let keyDisplay: String
        switch key {
        case "tab": keyDisplay = "⇥"
        case "left": keyDisplay = "←"
        case "right": keyDisplay = "→"
        case "up": keyDisplay = "↑"
        case "down": keyDisplay = "↓"
        case "escape": keyDisplay = "Esc"
        case "return": keyDisplay = "↩"
        case "space": keyDisplay = "Space"
        case "delete": keyDisplay = "⌫"
        default: keyDisplay = key.uppercased()
        }
        return modifiers.display + keyDisplay
    }
}

enum BrowserShortcutDefaults {
    static let values: [BrowserShortcutAction: BrowserShortcut] = [
        .newWindow: .init(key: "n", modifiers: [.command]),
        .newTab: .init(key: "t", modifiers: [.command]),
        .newPrivateTab: .init(key: "n", modifiers: [.command, .option]),
        .reopenClosedTab: .init(key: "t", modifiers: [.command, .shift]),
        .closeTab: .init(key: "w", modifiers: [.command]),
        .back: .init(key: "[", modifiers: [.command]),
        .forward: .init(key: "]", modifiers: [.command]),
        .reload: .init(key: "r", modifiers: [.command]),
        .focusAddress: .init(key: "l", modifiers: [.command]),
        .findInPage: .init(key: "f", modifiers: [.command]),
        .toggleSidebar: .init(key: "s", modifiers: [.command, .shift]),
        .searchTabs: .init(key: "a", modifiers: [.command, .shift]),
        .addSplit: .init(key: "s", modifiers: [.command, .option])
    ]
}

struct UserAccentColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    static let leafViolet = UserAccentColor(red: 0.51, green: 0.32, blue: 0.86, opacity: 1)
}

struct QuickLink: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var symbol: String

    static let defaults = [
        QuickLink(title: "LMS", url: "https://classroom.google.com", symbol: "graduationcap.fill"),
        QuickLink(title: "GitHub", url: "https://github.com", symbol: "chevron.left.forwardslash.chevron.right"),
        QuickLink(title: "ChatGPT", url: "https://chatgpt.com", symbol: "sparkles"),
        QuickLink(title: "YouTube", url: "https://youtube.com", symbol: "play.rectangle.fill"),
        QuickLink(title: "Spotify", url: "https://open.spotify.com", symbol: "music.note")
    ]
}

struct SettingsData: Codable {
    var searchEngine = SearchEngine.google; var customSearchTemplate = "https://example.com/search?q={query}"; var reopenSession = true; var askDownloadDestination = false
    var showFavicons = true; var showMediaIndicators = true; var compactTabs = false; var showSidebar = true
    var smartSuspension = true; var idleTimeout = 900.0; var suspensionAggressiveness = 0.6
    var keepPinnedTabsAlive = true; var keepExamTabsAlive = true
    var autoPiP = false; var keepMediaAlive = true
    var connectivityWarnings = true; var offlineOverlay = true; var suggestExamProtection = true
    var appearance = LeafAppearance.graphiteDark; var reducedTransparency = false; var diagnosticsMetrics = true; var onboardingCompleted = false
    var accent = UIAccent.violet; var density = InterfaceDensity.comfortable; var animationStyle = AnimationStyle.gentle
    var useCustomAccent = false; var useWorkspaceAccent = true; var customAccent = UserAccentColor.leafViolet
    var toolbarStyle = BrowserToolbarStyle.unified; var tabPlacement = TabPlacement.top
    var toolbarIconScale = ToolbarIconScale.regular
    var newTabBackgroundStyle = NewTabBackgroundStyle.ambient
    var showNetworkHUD = true; var networkPrivacyMode = NetworkPrivacyMode.system; var dnsProvider = "System Default"
    var developerMode = false; var webInspector = false; var showTerminalShortcut = false; var captureConsoleLogs = true
    var autoFillPasswords = true; var offerToSavePasswords = true; var passwordAutoLockMinutes = 5.0
    var showHomeButton = false; var showExamButton = true; var showDownloadsButton = true; var showBookmarksButton = true
    var showQuickLinks = true; var showRecentActivity = true
    var quickLinks = QuickLink.defaults
    var keyboardShortcuts = BrowserShortcutDefaults.values

    enum CodingKeys: String, CodingKey {
        case searchEngine, customSearchTemplate, reopenSession, askDownloadDestination, showFavicons, showMediaIndicators,
             compactTabs, showSidebar, smartSuspension, idleTimeout, suspensionAggressiveness, keepPinnedTabsAlive,
             keepExamTabsAlive, autoPiP, keepMediaAlive, connectivityWarnings,
             offlineOverlay, suggestExamProtection, appearance, reducedTransparency, diagnosticsMetrics,
             onboardingCompleted, accent, density, animationStyle, showNetworkHUD, networkPrivacyMode, dnsProvider,
             useCustomAccent, useWorkspaceAccent, customAccent, toolbarStyle, toolbarIconScale, tabPlacement, newTabBackgroundStyle,
             developerMode, webInspector, showTerminalShortcut, captureConsoleLogs, autoFillPasswords,
             offerToSavePasswords, passwordAutoLockMinutes, showHomeButton, showExamButton, showDownloadsButton,
             showBookmarksButton, showQuickLinks, showRecentActivity, quickLinks, keyboardShortcuts
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        searchEngine = try c.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) ?? .google
        customSearchTemplate = try c.decodeIfPresent(String.self, forKey: .customSearchTemplate) ?? "https://example.com/search?q={query}"
        reopenSession = try c.decodeIfPresent(Bool.self, forKey: .reopenSession) ?? true
        askDownloadDestination = try c.decodeIfPresent(Bool.self, forKey: .askDownloadDestination) ?? false
        showFavicons = try c.decodeIfPresent(Bool.self, forKey: .showFavicons) ?? true
        showMediaIndicators = try c.decodeIfPresent(Bool.self, forKey: .showMediaIndicators) ?? true
        compactTabs = try c.decodeIfPresent(Bool.self, forKey: .compactTabs) ?? false
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? true
        smartSuspension = try c.decodeIfPresent(Bool.self, forKey: .smartSuspension) ?? true
        idleTimeout = try c.decodeIfPresent(Double.self, forKey: .idleTimeout) ?? 900
        suspensionAggressiveness = try c.decodeIfPresent(Double.self, forKey: .suspensionAggressiveness) ?? 0.6
        keepPinnedTabsAlive = try c.decodeIfPresent(Bool.self, forKey: .keepPinnedTabsAlive) ?? true
        keepExamTabsAlive = try c.decodeIfPresent(Bool.self, forKey: .keepExamTabsAlive) ?? true
        autoPiP = try c.decodeIfPresent(Bool.self, forKey: .autoPiP) ?? false
        keepMediaAlive = try c.decodeIfPresent(Bool.self, forKey: .keepMediaAlive) ?? true
        connectivityWarnings = try c.decodeIfPresent(Bool.self, forKey: .connectivityWarnings) ?? true
        offlineOverlay = try c.decodeIfPresent(Bool.self, forKey: .offlineOverlay) ?? true
        suggestExamProtection = try c.decodeIfPresent(Bool.self, forKey: .suggestExamProtection) ?? true
        appearance = try c.decodeIfPresent(LeafAppearance.self, forKey: .appearance) ?? .graphiteDark
        reducedTransparency = try c.decodeIfPresent(Bool.self, forKey: .reducedTransparency) ?? false
        diagnosticsMetrics = try c.decodeIfPresent(Bool.self, forKey: .diagnosticsMetrics) ?? true
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        accent = try c.decodeIfPresent(UIAccent.self, forKey: .accent) ?? .violet
        density = try c.decodeIfPresent(InterfaceDensity.self, forKey: .density) ?? .comfortable
        animationStyle = try c.decodeIfPresent(AnimationStyle.self, forKey: .animationStyle) ?? .gentle
        useCustomAccent = try c.decodeIfPresent(Bool.self, forKey: .useCustomAccent) ?? false
        useWorkspaceAccent = try c.decodeIfPresent(Bool.self, forKey: .useWorkspaceAccent) ?? true
        customAccent = try c.decodeIfPresent(UserAccentColor.self, forKey: .customAccent) ?? .leafViolet
        toolbarStyle = try c.decodeIfPresent(BrowserToolbarStyle.self, forKey: .toolbarStyle) ?? .unified
        toolbarIconScale = try c.decodeIfPresent(ToolbarIconScale.self, forKey: .toolbarIconScale) ?? .regular
        tabPlacement = try c.decodeIfPresent(TabPlacement.self, forKey: .tabPlacement) ?? .top
        newTabBackgroundStyle = try c.decodeIfPresent(NewTabBackgroundStyle.self, forKey: .newTabBackgroundStyle) ?? .ambient
        showNetworkHUD = try c.decodeIfPresent(Bool.self, forKey: .showNetworkHUD) ?? true
        networkPrivacyMode = try c.decodeIfPresent(NetworkPrivacyMode.self, forKey: .networkPrivacyMode) ?? .system
        dnsProvider = try c.decodeIfPresent(String.self, forKey: .dnsProvider) ?? "System Default"
        developerMode = try c.decodeIfPresent(Bool.self, forKey: .developerMode) ?? false
        webInspector = try c.decodeIfPresent(Bool.self, forKey: .webInspector) ?? false
        showTerminalShortcut = try c.decodeIfPresent(Bool.self, forKey: .showTerminalShortcut) ?? false
        captureConsoleLogs = try c.decodeIfPresent(Bool.self, forKey: .captureConsoleLogs) ?? true
        autoFillPasswords = try c.decodeIfPresent(Bool.self, forKey: .autoFillPasswords) ?? true
        offerToSavePasswords = try c.decodeIfPresent(Bool.self, forKey: .offerToSavePasswords) ?? true
        passwordAutoLockMinutes = try c.decodeIfPresent(Double.self, forKey: .passwordAutoLockMinutes) ?? 5
        showHomeButton = try c.decodeIfPresent(Bool.self, forKey: .showHomeButton) ?? false
        showExamButton = try c.decodeIfPresent(Bool.self, forKey: .showExamButton) ?? true
        showDownloadsButton = try c.decodeIfPresent(Bool.self, forKey: .showDownloadsButton) ?? true
        showBookmarksButton = try c.decodeIfPresent(Bool.self, forKey: .showBookmarksButton) ?? true
        showQuickLinks = try c.decodeIfPresent(Bool.self, forKey: .showQuickLinks) ?? true
        showRecentActivity = try c.decodeIfPresent(Bool.self, forKey: .showRecentActivity) ?? true
        quickLinks = try c.decodeIfPresent([QuickLink].self, forKey: .quickLinks) ?? QuickLink.defaults
        keyboardShortcuts = try c.decodeIfPresent([BrowserShortcutAction: BrowserShortcut].self,
                                                  forKey: .keyboardShortcuts) ?? BrowserShortcutDefaults.values
        for (action, shortcut) in BrowserShortcutDefaults.values where keyboardShortcuts[action] == nil {
            keyboardShortcuts[action] = shortcut
        }
    }
}

@MainActor @Observable
final class SettingsStore {
    var value: SettingsData { didSet { save() } }
    private let defaults: UserDefaults; private let key = "settings.typed.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; value = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SettingsData.self, from: $0) } ?? SettingsData() }
    func validCustomSearchTemplate() -> Bool { value.customSearchTemplate.contains("{query}") && URL(string: value.customSearchTemplate.replacingOccurrences(of: "{query}", with: "test")) != nil }
    func resetMedia() { value.autoPiP = false; value.keepMediaAlive = true }
    func addQuickLink() { value.quickLinks.append(QuickLink(title: "New shortcut", url: "https://", symbol: "globe")) }
    func removeQuickLink(_ id: UUID) { value.quickLinks.removeAll { $0.id == id } }
    func resetQuickLinks() { value.quickLinks = QuickLink.defaults }
    func shortcut(for action: BrowserShortcutAction) -> BrowserShortcut {
        value.keyboardShortcuts[action] ?? BrowserShortcutDefaults.values[action]!
    }
    func setShortcut(_ shortcut: BrowserShortcut, for action: BrowserShortcutAction) {
        if let conflict = conflictingAction(for: shortcut, excluding: action) {
            value.keyboardShortcuts[conflict] = self.shortcut(for: action)
        }
        value.keyboardShortcuts[action] = shortcut
    }
    func resetKeyboardShortcuts() { value.keyboardShortcuts = BrowserShortcutDefaults.values }
    func conflictingAction(for shortcut: BrowserShortcut,
                           excluding action: BrowserShortcutAction) -> BrowserShortcutAction? {
        BrowserShortcutAction.allCases.first {
            $0 != action && self.shortcut(for: $0) == shortcut
        }
    }
    func resetToDefaults() { value = SettingsData() }
    private func save() { if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) } }
}
