import Foundation

enum LeafFormatting {
    static func mediaTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let value = Int(seconds.rounded(.down))
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let remainingSeconds = value % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%d:%02d", minutes, remainingSeconds)
    }

    static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 bytes" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    static func percentage(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    static func displayHost(_ url: URL?, fallback: String = "Website") -> String {
        guard let host = url?.host(percentEncoded: false), !host.isEmpty else {
            return fallback
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
