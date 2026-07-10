//
//  LeafOrLeaveTests.swift
//  LeafOrLeaveTests
//
//  Created by Bapakardhie Pacarnya Yaya on 11/07/26.
//

import Foundation
import Testing
@testable import LeafOrLeave

@MainActor
struct LeafOrLeaveTests {
    private let resolver = URLResolver()

    @Test func resolvesCompleteURL() {
        #expect(resolver.resolve("https://developer.apple.com")?.absoluteString == "https://developer.apple.com")
    }

    @Test func resolvesDomainWithoutScheme() {
        #expect(resolver.resolve("github.com")?.absoluteString == "https://github.com")
    }

    @Test func resolvesKeywordsAsGoogleSearch() {
        let url = resolver.resolve("Swift WKWebView")
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.host == "www.google.com")
        #expect(components?.queryItems?.first?.value == "Swift WKWebView")
    }

    @Test func workspaceDefaultsAndMutation() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let manager = WorkspaceManager(defaults: suite)
        #expect(manager.workspaces.map(\.name) == ["Study", "Coding", "Media"])
        manager.createWorkspace(name: "Research")
        let custom = manager.workspaces.last!
        manager.renameWorkspace(id: custom.id, name: "Thesis")
        #expect(manager.workspaces.last?.name == "Thesis")
        manager.deleteWorkspace(id: custom.id)
        #expect(manager.workspaces.count == 3)
    }

    @Test func workspaceMovesAndPinsTab() {
        let manager = WorkspaceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let tab = UUID(), target = manager.workspaces[1].id
        manager.moveTab(tab, to: target); manager.pinTab(tab, in: target)
        #expect(manager.workspaces[1].tabIDs.contains(tab))
        #expect(manager.workspaces[1].pinnedTabIDs.contains(tab))
        manager.unpinTab(tab, in: target)
        #expect(!manager.workspaces[1].pinnedTabIDs.contains(tab))
    }

    @Test func settingsDefaultsAndSearchValidation() {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(settings.value.appearance == .graphiteDark)
        settings.value.customSearchTemplate = "https://search.example/?q={query}"
        #expect(settings.validCustomSearchTemplate())
        settings.value.customSearchTemplate = "https://search.example/"
        #expect(!settings.validCustomSearchTemplate())
    }

    @Test func equalizerCompensatesPositiveGain() {
        let model = EqualizerViewModel()
        model.select(EqualizerPreset(name: "Test", gains: [6, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(model.preamp == -6)
    }
}
