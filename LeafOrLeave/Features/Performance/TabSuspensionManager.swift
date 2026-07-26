import Foundation
import Observation

@MainActor @Observable
final class TabSuspensionManager {
    var policy = PerformancePolicy()
    private(set) var lastEvaluation: Date?
    private(set) var lastActionCount = 0
    private let pressure: MemoryPressureMonitor
    private weak var tabs: TabManager?

    var pressureLevel: MemoryPressureLevel { pressure.level }
    var activeCount: Int { count(.active) }
    var backgroundCount: Int { count(.background) }
    var sleepingCount: Int { count(.sleeping) }
    var frozenCount: Int { count(.frozen) }
    var discardedCount: Int { count(.discarded) }

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

    func apply(_ settings: SettingsData) {
        policy.isEnabled = settings.smartSuspension
        policy.idleTimeout = settings.idleTimeout
        policy.aggressiveness = settings.suspensionAggressiveness
        policy.keepsMediaAlive = settings.keepMediaAlive
        policy.keepsExamTabsAlive = settings.keepExamTabsAlive
        policy.keepsPinnedTabsAlive = settings.keepPinnedTabsAlive
    }

    func evaluate() {
        guard policy.isEnabled, let tabs else { return }
        let eligible = eligibleTabs(in: tabs, respectsIdleTimeout: true)
        let normalThreshold = max(2, Int((14 - (policy.aggressiveness * 12)).rounded()))
        guard pressure.level != .normal || eligible.count >= normalThreshold else {
            lastEvaluation = Date()
            lastActionCount = 0
            return
        }

        let actionLimit = max(1, Int((policy.aggressiveness * 3).rounded(.up)))
        let targets = eligible.prefix(actionLimit)
        for tab in targets {
            switch pressure.level {
            case .critical: tab.discard()
            case .warning: tab.freeze()
            case .normal: tab.sleep()
            }
        }
        lastEvaluation = Date()
        lastActionCount = targets.count
        if lastActionCount > 0 {
            LeafLog.info(
                "Smart suspension processed \(lastActionCount) background tab(s)",
                category: .performance
            )
        }
    }

    func optimizeNow() {
        guard policy.isEnabled, let tabs else { return }
        let actionLimit = max(1, Int((policy.aggressiveness * 4).rounded(.up)))
        let targets = eligibleTabs(in: tabs, respectsIdleTimeout: false).prefix(actionLimit)
        targets.forEach { $0.freeze() }
        lastEvaluation = Date()
        lastActionCount = targets.count
        LeafLog.notice(
            "Manual optimization processed \(lastActionCount) background tab(s)",
            category: .performance
        )
    }

    private func eligibleTabs(in tabs: TabManager, respectsIdleTimeout: Bool) -> [BrowserTab] {
        tabs.tabs.filter { tab in
            !tabs.visibleTabIDs.contains(tab.id) &&
            tab.lifecycleState == .background &&
            !tab.isDownloading &&
            !tab.isUploading &&
            !(policy.keepsMediaAlive && (tab.isMediaPlaying || tab.isPictureInPicture)) &&
            !(policy.keepsExamTabsAlive && tab.isExamProtected) &&
            !(policy.keepsPinnedTabsAlive && tab.isPinned) &&
            (!respectsIdleTimeout || Date().timeIntervalSince(tab.lastActiveAt) >= policy.idleTimeout)
        }
        .sorted { $0.lastActiveAt < $1.lastActiveAt }
    }

    private func count(_ state: BrowserTabState) -> Int {
        tabs?.tabs.filter { $0.lifecycleState == state }.count ?? 0
    }
}
