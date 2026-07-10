import Foundation
import Observation

enum MemoryPressureLevel { case normal, warning, critical }

@MainActor @Observable
final class MemoryPressureMonitor {
    private(set) var level: MemoryPressureLevel = .normal
    private var source: DispatchSourceMemoryPressure?

    init() {
        let value = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        value.setEventHandler { [weak self, weak value] in
            guard let event = value?.data else { return }
            self?.level = event.contains(.critical) ? .critical : .warning
        }
        value.resume()
        source = value
    }
}
