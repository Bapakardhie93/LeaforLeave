import Foundation

struct PerformancePolicy {
    var isEnabled = true
    var idleTimeout: TimeInterval = 15 * 60
    var aggressiveness = 0.6
    var keepsMediaAlive = true
    var keepsExamTabsAlive = true
    var keepsPinnedTabsAlive = true
}
