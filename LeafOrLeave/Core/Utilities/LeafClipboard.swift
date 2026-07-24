import AppKit

@MainActor
enum LeafClipboard {
    private static var expirationTask: Task<Void, Never>?

    /// Copies text and can automatically remove sensitive values if the user
    /// has not copied something else in the meantime.
    @discardableResult
    static func copy(_ value: String, clearAfter seconds: Double? = nil) -> Bool {
        guard !value.isEmpty else { return false }
        expirationTask?.cancel()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(value, forType: .string) else { return false }

        guard let seconds, seconds > 0 else { return true }
        let expectedChangeCount = pasteboard.changeCount
        expirationTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled,
                  NSPasteboard.general.changeCount == expectedChangeCount else { return }
            NSPasteboard.general.clearContents()
        }
        return true
    }
}
