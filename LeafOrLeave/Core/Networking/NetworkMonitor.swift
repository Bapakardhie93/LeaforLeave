import Foundation
import Network
import Observation

enum NetworkQuality: String, Codable, CaseIterable {
    case excellent, good, weak, critical, offline

    var title: String { rawValue.capitalized }
}

@MainActor @Observable
final class NetworkMonitor {
    private(set) var quality: NetworkQuality = .good
    private(set) var isConnected = true
    private(set) var offlineSince: Date?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.leaforleave.network")

    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            Task { @MainActor in self.update(path) }
        }
        monitor.start(queue: queue)
    }

    private func update(_ path: NWPath) {
        let connected = path.status == .satisfied
        isConnected = connected
        if !connected {
            quality = .offline
            if offlineSince == nil { offlineSince = Date() }
        } else {
            if path.isConstrained { quality = .critical }
            else if path.isExpensive { quality = .weak }
            else { quality = path.availableInterfaces.contains(where: { $0.type == .wiredEthernet }) ? .excellent : .good }
            guard offlineSince != nil else { isConnected = true; return }
            Task { [weak self] in
                guard await ConnectivityProbe().validate() else { return }
                self?.isConnected = true
                self?.offlineSince = nil
            }
        }
    }
}
