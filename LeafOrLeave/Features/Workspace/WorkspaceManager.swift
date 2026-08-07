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

    @discardableResult
    func createWorkspace(name: String, symbolName: String = "square.grid.2x2", accentToken: String = "purple") -> UUID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !name.isEmpty else { return nil }
        let id = UUID()
        let now = Date(); workspaces.append(.init(id: id, name: name, symbolName: symbolName, accentToken: accentToken, tabIDs: [], pinnedTabIDs: [], selectedTabID: nil, createdAt: now, updatedAt: now, isDefault: false, homePage: nil, accentName: nil)); save()
        return id
    }
    func renameWorkspace(id: UUID, name: String) { guard let i = index(id), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; workspaces[i].name = name; touch(i) }
    func setSymbol(id: UUID, symbol: String) { guard let i = index(id) else { return }; workspaces[i].symbolName = symbol; touch(i) }
    func setHomePage(id: UUID, value: String) { guard let i = index(id) else { return }; workspaces[i].homePage = value.trimmingCharacters(in: .whitespacesAndNewlines); touch(i) }
    func setAccent(id: UUID, value: String) { guard let i = index(id) else { return }; workspaces[i].accentName = value; touch(i) }
    func deleteWorkspace(id: UUID) {
        guard let i = index(id), !workspaces[i].isDefault else { return }
        let removed = workspaces[i]
        workspaces.remove(at: i)
        if selectedWorkspaceID == id { selectedWorkspaceID = workspaces.first?.id }
        if let targetID = selectedWorkspaceID ?? workspaces.first?.id, let target = index(targetID) {
            let claimed = Set(workspaces.flatMap(\.tabIDs))
            let displaced = removed.tabIDs.filter { !claimed.contains($0) }
            workspaces[target].tabIDs.append(contentsOf: displaced)
            workspaces[target].pinnedTabIDs.append(
                contentsOf: removed.pinnedTabIDs.filter(displaced.contains)
            )
            if workspaces[target].selectedTabID == nil {
                workspaces[target].selectedTabID = removed.selectedTabID.flatMap {
                    displaced.contains($0) ? $0 : nil
                } ?? displaced.first
            }
            workspaces[target].updatedAt = Date()
        }
        save()
    }
    func selectWorkspace(id: UUID) { guard index(id) != nil else { return }; selectedWorkspaceID = id }
    func assignUnownedTabs(_ ids: [UUID]) {
        reconcileTabs(ids, assigningUnownedTo: selectedWorkspaceID)
    }
    func reconcileTabs(_ ids: [UUID], assigningUnownedTo workspaceID: UUID? = nil) {
        guard !workspaces.isEmpty else { return }
        let validIDs = Set(ids)
        var claimed = Set<UUID>()

        for i in workspaces.indices {
            workspaces[i].tabIDs = workspaces[i].tabIDs.filter {
                validIDs.contains($0) && claimed.insert($0).inserted
            }
            let owned = Set(workspaces[i].tabIDs)
            workspaces[i].pinnedTabIDs = workspaces[i].pinnedTabIDs.filter(owned.contains)
            if let selected = workspaces[i].selectedTabID, !owned.contains(selected) {
                workspaces[i].selectedTabID = nil
            }
        }

        let targetID = workspaceID ?? selectedWorkspaceID ?? workspaces.first?.id
        if let targetID, let target = index(targetID) {
            let unowned = ids.filter { claimed.insert($0).inserted }
            workspaces[target].tabIDs.append(contentsOf: unowned)
            if workspaces[target].selectedTabID == nil {
                workspaces[target].selectedTabID = unowned.last ?? workspaces[target].tabIDs.first
            }
            if !unowned.isEmpty { workspaces[target].updatedAt = Date() }
        }
        save()
    }
    func moveTab(_ tabID: UUID, to workspaceID: UUID) { for i in workspaces.indices { workspaces[i].tabIDs.removeAll { $0 == tabID }; workspaces[i].pinnedTabIDs.removeAll { $0 == tabID } }; guard let i = index(workspaceID) else { return }; workspaces[i].tabIDs.append(tabID); workspaces[i].selectedTabID = tabID; touch(i) }
    func pinTab(_ tabID: UUID, in workspaceID: UUID) { guard let i = index(workspaceID), !workspaces[i].pinnedTabIDs.contains(tabID) else { return }; workspaces[i].pinnedTabIDs.append(tabID); touch(i) }
    func unpinTab(_ tabID: UUID, in workspaceID: UUID) { guard let i = index(workspaceID) else { return }; workspaces[i].pinnedTabIDs.removeAll { $0 == tabID }; touch(i) }
    func rememberSelection(_ tabID: UUID?) {
        guard let id = selectedWorkspaceID, let i = index(id) else { return }
        if let tabID, !workspaces[i].tabIDs.contains(tabID) { return }
        workspaces[i].selectedTabID = tabID
        touch(i)
    }
    func reorderWorkspaces(from: IndexSet, to: Int) { workspaces.move(fromOffsets: from, toOffset: to); save() }
    func restoreTemplates(_ templates: [WorkspaceBackupTemplate]) {
        for template in templates.prefix(100) {
            let name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if let existing = workspaces.firstIndex(where: {
                $0.name.compare(name, options: .caseInsensitive) == .orderedSame
            }) {
                workspaces[existing].symbolName = template.symbolName
                workspaces[existing].accentToken = template.accentToken
                workspaces[existing].accentName = template.accentName
                workspaces[existing].homePage = template.homePage
                workspaces[existing].updatedAt = .now
            } else {
                let now = Date()
                workspaces.append(BrowserWorkspace(
                    id: UUID(), name: name, symbolName: template.symbolName,
                    accentToken: template.accentToken, tabIDs: [], pinnedTabIDs: [],
                    selectedTabID: nil, createdAt: now, updatedAt: now,
                    isDefault: false, homePage: template.homePage,
                    accentName: template.accentName
                ))
            }
        }
        save()
    }
    func restoreDefaultWorkspacesIfNeeded() { if workspaces.isEmpty { let now = Date(); workspaces = [("Study","graduationcap.fill","purple"),("Coding","chevron.left.forwardslash.chevron.right","blue"),("Media","play.rectangle.fill","pink")].map { .init(id: UUID(), name: $0.0, symbolName: $0.1, accentToken: $0.2, tabIDs: [], pinnedTabIDs: [], selectedTabID: nil, createdAt: now, updatedAt: now, isDefault: true, homePage: nil, accentName: $0.2) }; save() } }
    private func index(_ id: UUID) -> Int? { workspaces.firstIndex { $0.id == id } }
    private func touch(_ i: Int) { workspaces[i].updatedAt = Date(); save() }
    private func save() { if let data = try? JSONEncoder().encode(workspaces) { defaults.set(data, forKey: key) }; defaults.set(selectedWorkspaceID?.uuidString, forKey: "workspaces.selected") }
}
