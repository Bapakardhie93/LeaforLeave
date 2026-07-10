import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class WorkspaceManager {
    private(set) var workspaces: [BrowserWorkspace] = []
    var selectedWorkspaceID: UUID? { didSet { save() } }
    var selectedWorkspace: BrowserWorkspace? { workspaces.first { $0.id == selectedWorkspaceID } }
    private let defaults: UserDefaults
    private let key = "workspaces.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode([BrowserWorkspace].self, from: data), !value.isEmpty { workspaces = value }
        restoreDefaultWorkspacesIfNeeded()
        selectedWorkspaceID = UUID(uuidString: defaults.string(forKey: "workspaces.selected") ?? "") ?? workspaces.first?.id
    }

    func createWorkspace(name: String, symbolName: String = "square.grid.2x2", accentToken: String = "purple") {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return }
        let now = Date(); workspaces.append(.init(id: UUID(), name: name, symbolName: symbolName, accentToken: accentToken, tabIDs: [], pinnedTabIDs: [], selectedTabID: nil, createdAt: now, updatedAt: now, isDefault: false)); save()
    }
    func renameWorkspace(id: UUID, name: String) { guard let i = index(id), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; workspaces[i].name = name; touch(i) }
    func deleteWorkspace(id: UUID) { guard let i = index(id), !workspaces[i].isDefault else { return }; workspaces.remove(at: i); if selectedWorkspaceID == id { selectedWorkspaceID = workspaces.first?.id }; save() }
    func selectWorkspace(id: UUID) { guard index(id) != nil else { return }; selectedWorkspaceID = id }
    func assignUnownedTabs(_ ids: [UUID]) { guard !workspaces.isEmpty else { return }; for id in ids where !workspaces.contains(where: { $0.tabIDs.contains(id) }) { workspaces[0].tabIDs.append(id) }; save() }
    func moveTab(_ tabID: UUID, to workspaceID: UUID) { for i in workspaces.indices { workspaces[i].tabIDs.removeAll { $0 == tabID }; workspaces[i].pinnedTabIDs.removeAll { $0 == tabID } }; guard let i = index(workspaceID) else { return }; workspaces[i].tabIDs.append(tabID); workspaces[i].selectedTabID = tabID; touch(i) }
    func pinTab(_ tabID: UUID, in workspaceID: UUID) { guard let i = index(workspaceID), !workspaces[i].pinnedTabIDs.contains(tabID) else { return }; workspaces[i].pinnedTabIDs.append(tabID); touch(i) }
    func unpinTab(_ tabID: UUID, in workspaceID: UUID) { guard let i = index(workspaceID) else { return }; workspaces[i].pinnedTabIDs.removeAll { $0 == tabID }; touch(i) }
    func rememberSelection(_ tabID: UUID?) { guard let id = selectedWorkspaceID, let i = index(id) else { return }; workspaces[i].selectedTabID = tabID; touch(i) }
    func reorderWorkspaces(from: IndexSet, to: Int) { workspaces.move(fromOffsets: from, toOffset: to); save() }
    func restoreDefaultWorkspacesIfNeeded() { if workspaces.isEmpty { let now = Date(); workspaces = [("Study","graduationcap.fill","purple"),("Coding","chevron.left.forwardslash.chevron.right","blue"),("Media","play.rectangle.fill","pink")].map { .init(id: UUID(), name: $0.0, symbolName: $0.1, accentToken: $0.2, tabIDs: [], pinnedTabIDs: [], selectedTabID: nil, createdAt: now, updatedAt: now, isDefault: true) }; save() } }
    private func index(_ id: UUID) -> Int? { workspaces.firstIndex { $0.id == id } }
    private func touch(_ i: Int) { workspaces[i].updatedAt = Date(); save() }
    private func save() { if let data = try? JSONEncoder().encode(workspaces) { defaults.set(data, forKey: key) }; defaults.set(selectedWorkspaceID?.uuidString, forKey: "workspaces.selected") }
}
