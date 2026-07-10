import Foundation
import Observation

@MainActor @Observable
final class ExamProtectionManager {
    private(set) var snapshots: [UUID: FormSnapshot] = [:]
    let snapshotService = FormSnapshotService()

    func protect(_ tab: BrowserTab, enabled: Bool) {
        tab.isExamProtected = enabled
        if enabled { Task { await snapshot(tab) } } else { snapshots[tab.id] = nil }
    }

    func snapshot(_ tab: BrowserTab) async {
        if let value = await snapshotService.capture(from: tab.webView) { snapshots[tab.id] = value }
    }
    func clear() { snapshots.removeAll() }
}
