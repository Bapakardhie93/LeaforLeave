import Foundation

struct DiagnosticsService {
    func report(tabs: TabManager, network: NetworkMonitor, workspace: WorkspaceManager) -> String {
        let counts = Dictionary(grouping: tabs.tabs, by: \.lifecycleState).mapValues(\.count)
        let recentEvents = LeafLogStore.shared.entries(limit: 40).map {
            [
                "timestamp": $0.date.ISO8601Format(),
                "level": $0.level.rawValue,
                "category": $0.category.rawValue,
                "event": $0.message
            ]
        }
        let payload: [String: Any] = [
            "app": "LeafOrLeave",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": SystemInfo.machine,
            "tabs": tabs.tabs.count,
            "tabStates": counts.mapKeys { $0.rawValue },
            "network": network.quality.rawValue,
            "workspace": workspace.selectedWorkspace?.name ?? "None",
            "recentOperationalEvents": recentEvents
        ]
        let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        return data.flatMap { String(data: $0, encoding: .utf8) }
            ?? "Diagnostics unavailable"
    }
}

private enum SystemInfo {
    static var machine: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

private extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
