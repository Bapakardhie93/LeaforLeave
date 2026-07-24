import Foundation
import OSLog

enum LeafLogCategory: String, Sendable {
    case app
    case browser
    case network
    case downloads
    case passwords
    case performance
    case persistence
}

enum LeafLogLevel: String, Sendable {
    case debug
    case info
    case notice
    case warning
    case error
}

struct LeafLogEntry: Equatable, Sendable {
    let date: Date
    let level: LeafLogLevel
    let category: LeafLogCategory
    let message: String
}

/// A bounded, privacy-safe operational event buffer used by diagnostics.
///
/// Callers should record state transitions and error codes, never URLs,
/// credentials, form values, cookies, or authentication tokens.
final class LeafLogStore: @unchecked Sendable {
    static let shared = LeafLogStore()

    private let capacity: Int
    private let lock = NSLock()
    private var storage: [LeafLogEntry] = []
    private var collectionEnabled = true

    init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    func append(_ entry: LeafLogEntry) {
        lock.lock()
        defer { lock.unlock() }
        guard collectionEnabled else { return }
        storage.append(entry)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    func entries(limit: Int = 50) -> [LeafLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.suffix(max(0, limit)))
    }

    func setCollectionEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        collectionEnabled = enabled
        if !enabled { storage.removeAll(keepingCapacity: false) }
    }
}

enum LeafLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.leaforleave.LeafOrLeave"
    private static let appLogger = Logger(subsystem: subsystem, category: LeafLogCategory.app.rawValue)
    private static let browserLogger = Logger(subsystem: subsystem, category: LeafLogCategory.browser.rawValue)
    private static let networkLogger = Logger(subsystem: subsystem, category: LeafLogCategory.network.rawValue)
    private static let downloadLogger = Logger(subsystem: subsystem, category: LeafLogCategory.downloads.rawValue)
    private static let passwordLogger = Logger(subsystem: subsystem, category: LeafLogCategory.passwords.rawValue)
    private static let performanceLogger = Logger(subsystem: subsystem, category: LeafLogCategory.performance.rawValue)
    private static let persistenceLogger = Logger(subsystem: subsystem, category: LeafLogCategory.persistence.rawValue)

    static func debug(_ message: String, category: LeafLogCategory) {
        write(message, level: .debug, category: category)
    }

    static func info(_ message: String, category: LeafLogCategory) {
        write(message, level: .info, category: category)
    }

    static func notice(_ message: String, category: LeafLogCategory) {
        write(message, level: .notice, category: category)
    }

    static func warning(_ message: String, category: LeafLogCategory) {
        write(message, level: .warning, category: category)
    }

    static func error(_ message: String, category: LeafLogCategory) {
        write(message, level: .error, category: category)
    }

    private static func write(
        _ message: String,
        level: LeafLogLevel,
        category: LeafLogCategory
    ) {
        let logger = logger(for: category)
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .notice:
            logger.notice("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
        LeafLogStore.shared.append(
            LeafLogEntry(date: Date(), level: level, category: category, message: message)
        )
    }

    private static func logger(for category: LeafLogCategory) -> Logger {
        switch category {
        case .app: appLogger
        case .browser: browserLogger
        case .network: networkLogger
        case .downloads: downloadLogger
        case .passwords: passwordLogger
        case .performance: performanceLogger
        case .persistence: persistenceLogger
        }
    }
}
