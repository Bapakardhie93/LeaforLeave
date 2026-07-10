import Foundation
import Observation

@MainActor @Observable
final class TabSuspensionManager {
    var policy = PerformancePolicy()
    private let pressure: MemoryPressureMonitor
    private weak var tabs: TabManager?

    init(tabs: TabManager, pressure: MemoryPressureMonitor) {
        self.tabs = tabs; self.pressure = pressure
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.evaluate()
            }
        }
    }

    convenience init(tabs: TabManager) { self.init(tabs: tabs, pressure: MemoryPressureMonitor()) }

    func evaluate() {
        guard policy.isEnabled, let tabs else { return }
        let eligible = tabs.tabs.filter { tab in
            tab.id != tabs.selectedTabID && !tab.isDownloading && !tab.isUploading &&
            !(policy.keepsMediaAlive && (tab.isMediaPlaying || tab.isPictureInPicture)) &&
            !(policy.keepsExamTabsAlive && tab.isExamProtected) &&
            Date().timeIntervalSince(tab.lastActiveAt) >= policy.idleTimeout
        }.sorted { $0.lastActiveAt < $1.lastActiveAt }
        guard let tab = eligible.first else { return }
        switch pressure.level {
        case .critical: tab.discard()
        case .warning: tab.freeze()
        case .normal: if eligible.count > 12 { tab.sleep() }
        }
    }
}
