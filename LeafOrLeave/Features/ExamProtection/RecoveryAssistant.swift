import AppKit

enum RecoveryAssistant {
    static func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}
