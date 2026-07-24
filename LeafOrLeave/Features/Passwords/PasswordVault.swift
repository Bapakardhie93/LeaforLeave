import Foundation
import LocalAuthentication
import Observation
import Security

struct PasswordCredential: Identifiable, Codable, Equatable {
    let id: UUID
    var host: String
    var username: String
    var password: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), host: String, username: String, password: String,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.host = PasswordCredential.normalized(host)
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalized(_ value: String) -> String {
        let candidate = value.contains("://") ? value : "https://\(value)"
        let host = URL(string: candidate)?.host ?? value
        return host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

enum PasswordVaultError: LocalizedError {
    case locked
    case invalidCredential
    case keychain(OSStatus)
    case authentication(String)

    var errorDescription: String? {
        switch self {
        case .locked:
            "Password Vault is locked."
        case .invalidCredential:
            "Enter a website, username, and password."
        case let .keychain(status):
            (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)."
        case let .authentication(message):
            message
        }
    }
}

@MainActor
@Observable
final class PasswordVault {
    typealias Authenticator = @MainActor @Sendable (String) async throws -> Void

    private(set) var credentials: [PasswordCredential] = []
    private(set) var isUnlocked = false
    private(set) var unlockedUntil: Date?
    private(set) var lastError: String?

    private let service: String
    private let authenticator: Authenticator
    private var lockTask: Task<Void, Never>?

    init(
        service: String = "\(Bundle.main.bundleIdentifier ?? "app.leaforleave.LeafOrLeave").passwords",
        authenticator: Authenticator? = nil
    ) {
        self.service = service
        self.authenticator = authenticator ?? Self.authenticateDeviceOwner
    }

    var storedCredentialCount: Int {
        (try? storedMetadata().count) ?? 0
    }

    func hasStoredCredential(for host: String) -> Bool {
        let normalized = PasswordCredential.normalized(host)
        return (try? storedMetadata().contains { $0.host == normalized }) ?? false
    }

    @discardableResult
    func unlock(reason: String, autoLockMinutes: Double = 5) async -> Bool {
        if isUnlocked {
            scheduleAutoLock(minutes: autoLockMinutes)
            return true
        }

        do {
            try await authenticator(reason)
            credentials = try loadCredentials()
            isUnlocked = true
            lastError = nil
            scheduleAutoLock(minutes: autoLockMinutes)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func lock() {
        lockTask?.cancel()
        lockTask = nil
        credentials.removeAll(keepingCapacity: false)
        isUnlocked = false
        unlockedUntil = nil
    }

    func clearError() {
        lastError = nil
    }

    @discardableResult
    func save(host: String, username: String, password: String, id: UUID? = nil) throws -> PasswordCredential {
        guard isUnlocked else { throw PasswordVaultError.locked }
        let normalizedHost = PasswordCredential.normalized(host)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty, !trimmedUsername.isEmpty, !password.isEmpty else {
            throw PasswordVaultError.invalidCredential
        }

        let existing = id.flatMap { value in credentials.first { $0.id == value } }
            ?? credentials.first { $0.host == normalizedHost && $0.username == trimmedUsername }
        let credential = PasswordCredential(
            id: existing?.id ?? UUID(),
            host: normalizedHost,
            username: trimmedUsername,
            password: password,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        try write(credential)
        credentials.removeAll { $0.id == credential.id }
        credentials.append(credential)
        credentials.sort { $0.updatedAt > $1.updatedAt }
        return credential
    }

    func delete(_ credential: PasswordCredential) throws {
        guard isUnlocked else { throw PasswordVaultError.locked }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credential.id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PasswordVaultError.keychain(status)
        }
        credentials.removeAll { $0.id == credential.id }
    }

    func credential(for host: String) -> PasswordCredential? {
        guard isUnlocked else { return nil }
        return credentials(for: host).first
    }

    func credentials(for host: String) -> [PasswordCredential] {
        guard isUnlocked else { return [] }
        let normalized = PasswordCredential.normalized(host)
        return credentials
            .filter { $0.host == normalized }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func loadCredentials() throws -> [PasswordCredential] {
        // On current macOS releases, asking Security.framework for every
        // generic-password data blob in one query can return errSecParam.
        // Enumerate non-secret attributes first, then fetch each encrypted
        // payload individually. This also lets one damaged entry be skipped
        // without making the entire vault unavailable.
        let values = try storedMetadata().compactMap { metadata in
            try readCredentialData(account: metadata.account)
        }
        return values.compactMap { try? JSONDecoder().decode(PasswordCredential.self, from: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func readCredentialData(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw PasswordVaultError.keychain(status)
        }
        return item as? Data
    }

    private func write(_ credential: PasswordCredential) throws {
        let data = try JSONEncoder().encode(credential)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credential.id.uuidString
        ]
        let updates: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrLabel as String: credential.host,
            kSecAttrComment as String: credential.host
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var attributes = query
            updates.forEach { attributes[$0.key] = $0.value }
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw PasswordVaultError.keychain(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw PasswordVaultError.keychain(updateStatus)
        }
    }

    private func storedMetadata() throws -> [(host: String, account: String)] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else {
            throw PasswordVaultError.keychain(status)
        }
        let items = item as? [[String: Any]] ?? (item as? [String: Any]).map { [$0] } ?? []
        return items.compactMap { attributes in
            guard let host = attributes[kSecAttrComment as String] as? String,
                  let account = attributes[kSecAttrAccount as String] as? String else { return nil }
            return (PasswordCredential.normalized(host), account)
        }
    }

    private func scheduleAutoLock(minutes: Double) {
        lockTask?.cancel()
        let duration = max(1, minutes) * 60
        unlockedUntil = Date().addingTimeInterval(duration)
        lockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }

    private static func authenticateDeviceOwner(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Keep Locked"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            throw PasswordVaultError.authentication(
                policyError?.localizedDescription
                    ?? "Touch ID or the Mac login password is unavailable."
            )
        }
        try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
    }
}
