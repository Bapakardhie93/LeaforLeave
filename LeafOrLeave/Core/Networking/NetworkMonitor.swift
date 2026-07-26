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
    private(set) var latencyMS: Int?
    private(set) var lastLatencyUpdate: Date?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.leaforleave.network")
    @ObservationIgnored nonisolated(unsafe) private var latencyTask: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            Task { @MainActor in self.update(path) }
        }
        monitor.start(queue: queue)
        latencyTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.measureLatency()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    deinit {
        monitor.cancel()
        latencyTask?.cancel()
    }

    private func update(_ path: NWPath) {
        let previousQuality = quality
        let wasConnected = isConnected
        let connected = path.status == .satisfied
        isConnected = connected
        if !connected {
            quality = .offline
            if offlineSince == nil { offlineSince = Date() }
        } else {
            if path.isConstrained { quality = .critical }
            else if path.isExpensive { quality = .weak }
            else { quality = path.availableInterfaces.contains(where: { $0.type == .wiredEthernet }) ? .excellent : .good }
            if offlineSince != nil {
                Task { [weak self] in
                    _ = await self?.validateConnectivity()
                }
            }
        }
        if wasConnected != connected || previousQuality != quality {
            LeafLog.info("Network quality changed to \(quality.rawValue)", category: .network)
        }
    }

    func refreshLatency() { Task { await measureLatency() } }

    @discardableResult
    func validateConnectivity() async -> Bool {
        guard await ConnectivityProbe().validate() else { return false }
        let wasOffline = !isConnected || offlineSince != nil
        isConnected = true
        offlineSince = nil
        if quality == .offline { quality = .good }
        if wasOffline {
            LeafLog.notice("Internet connectivity restored", category: .network)
        }
        await measureLatency()
        return true
    }

    private func measureLatency() async {
        guard isConnected else { latencyMS = nil; return }
        var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 1
        let clock = ContinuousClock()
        let start = clock.now
        guard (try? await URLSession.shared.data(for: request)) != nil else {
            latencyMS = nil
            lastLatencyUpdate = Date()
            return
        }
        latencyMS = Int(start.duration(to: clock.now).components.attoseconds / 1_000_000_000_000_000)
        lastLatencyUpdate = Date()
    }
}
