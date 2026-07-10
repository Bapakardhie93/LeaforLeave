import Foundation

struct PerformancePolicy {
    var isEnabled = true
    var idleTimeout: TimeInterval = 15 * 60
    var keepsMediaAlive = true
    var keepsExamTabsAlive = true
}
