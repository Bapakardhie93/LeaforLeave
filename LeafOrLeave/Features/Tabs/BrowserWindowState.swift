import CoreGraphics
import Foundation
import Observation

extension Notification.Name {
    static let leafBrowserWindowShouldClose = Notification.Name("LeafOrLeave.BrowserWindowShouldClose")
}

@MainActor
@Observable
final class BrowserWindowState: Identifiable {
    let id: UUID
    var tabIDs: [UUID]
    var workspaceID: UUID?
    var visibleTabIDs: [UUID]
    var focusedTabID: UUID?
    var splitFractions: [Double]
    @ObservationIgnored var frame: CGRect?

    var isSplit: Bool { visibleTabIDs.count > 1 }
    var canAddSplit: Bool { visibleTabIDs.count < 3 }

    init(id: UUID = UUID(), tabIDs: [UUID] = [], workspaceID: UUID? = nil,
         visibleTabIDs: [UUID] = [], focusedTabID: UUID? = nil,
         splitFractions: [Double] = [], frame: CGRect? = nil) {
        self.id = id
        self.tabIDs = tabIDs
        self.workspaceID = workspaceID
        self.visibleTabIDs = Array(visibleTabIDs.prefix(3))
        self.focusedTabID = focusedTabID
        self.splitFractions = splitFractions
        self.frame = frame
        normalize()
    }

    convenience init(record: BrowserWindowSessionRecord, validTabIDs: Set<UUID>) {
        let owned = record.tabIDs.filter(validTabIDs.contains)
        self.init(
            id: record.id,
            tabIDs: owned,
            workspaceID: record.workspaceID,
            visibleTabIDs: record.visibleTabIDs.filter(owned.contains),
            focusedTabID: record.focusedTabID.flatMap { owned.contains($0) ? $0 : nil },
            splitFractions: record.splitFractions,
            frame: record.frame
        )
    }

    func select(_ tabID: UUID) {
        guard tabIDs.contains(tabID) else { return }
        if let visibleIndex = visibleTabIDs.firstIndex(of: tabID) {
            focusedTabID = visibleTabIDs[visibleIndex]
        } else if isSplit, let focusedTabID,
                  let focusedIndex = visibleTabIDs.firstIndex(of: focusedTabID) {
            visibleTabIDs[focusedIndex] = tabID
            self.focusedTabID = tabID
        } else {
            visibleTabIDs = [tabID]
            focusedTabID = tabID
        }
        normalize()
    }

    @discardableResult
    func addSplit(_ tabID: UUID) -> Bool {
        guard tabIDs.contains(tabID) else { return false }
        if visibleTabIDs.contains(tabID) {
            focusedTabID = tabID
            return true
        }
        guard canAddSplit else { return false }
        visibleTabIDs.append(tabID)
        focusedTabID = tabID
        normalize()
        return true
    }

    func removeSplit(_ tabID: UUID) {
        guard visibleTabIDs.count > 1 else { return }
        visibleTabIDs.removeAll { $0 == tabID }
        focusedTabID = visibleTabIDs.last
        normalize()
    }

    func exitSplit(keeping tabID: UUID? = nil) {
        let kept = tabID.flatMap { visibleTabIDs.contains($0) ? $0 : nil }
            ?? focusedTabID.flatMap { visibleTabIDs.contains($0) ? $0 : nil }
            ?? visibleTabIDs.first
        visibleTabIDs = kept.map { [$0] } ?? []
        focusedTabID = kept
        normalize()
    }

    func removeTab(_ tabID: UUID) {
        tabIDs.removeAll { $0 == tabID }
        visibleTabIDs.removeAll { $0 == tabID }
        if focusedTabID == tabID { focusedTabID = visibleTabIDs.last ?? tabIDs.last }
        normalize()
    }

    func insertTab(_ tabID: UUID, activate: Bool = true) {
        if !tabIDs.contains(tabID) { tabIDs.append(tabID) }
        if activate { select(tabID) }
        else { normalize() }
    }

    func normalize() {
        var seen = Set<UUID>()
        tabIDs = tabIDs.filter { seen.insert($0).inserted }
        seen.removeAll()
        visibleTabIDs = visibleTabIDs
            .filter { tabIDs.contains($0) && seen.insert($0).inserted }
        visibleTabIDs = Array(visibleTabIDs.prefix(3))
        normalizeSplitFractions()
        if visibleTabIDs.isEmpty, let fallback = focusedTabID.flatMap({ tabIDs.contains($0) ? $0 : nil }) ?? tabIDs.first {
            visibleTabIDs = [fallback]
        }
        if let focusedTabID, visibleTabIDs.contains(focusedTabID) == false {
            self.focusedTabID = visibleTabIDs.first
        } else if focusedTabID == nil {
            focusedTabID = visibleTabIDs.first
        }
        normalizeSplitFractions()
    }

    func setSplitFractions(_ values: [Double]) {
        guard values.count == visibleTabIDs.count, values.allSatisfy({ $0.isFinite && $0 > 0 }) else { return }
        let total = values.reduce(0, +)
        guard total > 0 else { return }
        splitFractions = values.map { $0 / total }
    }

    static func resizedSplitFractions(
        from startingValues: [Double],
        after dividerIndex: Int,
        translation: Double,
        availableWidth: Double,
        minimumPanelWidth: Double = 180
    ) -> [Double] {
        guard availableWidth > 0,
              startingValues.indices.contains(dividerIndex),
              startingValues.indices.contains(dividerIndex + 1),
              startingValues.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return startingValues
        }

        var values = startingValues
        let pairTotal = values[dividerIndex] + values[dividerIndex + 1]
        let minimumFraction = min(minimumPanelWidth / availableWidth, pairTotal / 2)
        let requestedDelta = translation / availableWidth
        let lowerBound = minimumFraction - values[dividerIndex]
        let upperBound = values[dividerIndex + 1] - minimumFraction
        let delta = min(max(requestedDelta, lowerBound), upperBound)

        values[dividerIndex] += delta
        values[dividerIndex + 1] -= delta
        let total = values.reduce(0, +)
        return total > 0 ? values.map { $0 / total } : startingValues
    }

    private func normalizeSplitFractions() {
        guard !visibleTabIDs.isEmpty else {
            splitFractions = []
            return
        }
        guard splitFractions.count == visibleTabIDs.count,
              splitFractions.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            splitFractions = Array(repeating: 1 / Double(visibleTabIDs.count), count: visibleTabIDs.count)
            return
        }
        let total = splitFractions.reduce(0, +)
        splitFractions = splitFractions.map { $0 / total }
    }

    var sessionRecord: BrowserWindowSessionRecord {
        sessionRecord(including: Set(tabIDs))
    }

    func sessionRecord(including validTabIDs: Set<UUID>) -> BrowserWindowSessionRecord {
        let persistentTabIDs = tabIDs.filter(validTabIDs.contains)
        let persistentVisibleIDs = visibleTabIDs.filter(validTabIDs.contains)
        let persistentFocus = focusedTabID.flatMap { validTabIDs.contains($0) ? $0 : nil }
        return BrowserWindowSessionRecord(
            id: id,
            tabIDs: persistentTabIDs,
            workspaceID: workspaceID,
            visibleTabIDs: persistentVisibleIDs,
            focusedTabID: persistentFocus,
            splitFractions: persistentVisibleIDs.count == visibleTabIDs.count ? splitFractions : [],
            frame: frame
        )
    }
}
