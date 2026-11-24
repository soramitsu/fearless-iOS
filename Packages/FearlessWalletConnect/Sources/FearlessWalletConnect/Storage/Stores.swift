import Foundation
import Security

/// Where the client keeps its record (sessions, pairings, proposals; no keys).
public protocol WalletConnectStateStore: AnyObject, Sendable {
    func loadState() throws -> Data?
    func saveState(_ data: Data) throws
}

/// Where the client keeps its secrets: the relay identity and the topic keys.
public protocol WalletConnectSecretStore: AnyObject, Sendable {
    func loadSecrets() throws -> Data?
    func saveSecrets(_ data: Data) throws
}

public enum WalletConnectStoreError: Error, Equatable {
    case keychain(OSStatus)
}

/// The record in user defaults (the app group's, in the app).
public final class UserDefaultsStateStore: WalletConnectStateStore, @unchecked Sendable {
    public static let defaultKey = "jp.co.soramitsu.fearless.walletconnect.state.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults, key: String = UserDefaultsStateStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func loadState() throws -> Data? {
        defaults.data(forKey: key)
    }

    public func saveState(_ data: Data) throws {
        defaults.set(data, forKey: key)
    }
}

/// The secrets in one keychain item, readable after the first unlock and never leaving this device.
public final class KeychainSecretStore: WalletConnectSecretStore, @unchecked Sendable {
    public static let defaultService = "jp.co.soramitsu.fearless.walletconnect"
    public static let defaultAccount = "secrets.v1"

    private let service: String
    private let account: String
    private let accessGroup: String?

    public init(
        service: String = KeychainSecretStore.defaultService,
        account: String = KeychainSecretStore.defaultAccount,
        accessGroup: String?
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    private func baseQuery() -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        return query
    }

    public func loadSecrets() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw WalletConnectStoreError.keychain(status)
        }
    }

    public func saveSecrets(_ data: Data) throws {
        let query = baseQuery()
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw WalletConnectStoreError.keychain(status)
        }
    }

    /// Removes the item; for tests and for a full wallet reset.
    public func deleteSecrets() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}

/// Both stores in memory, for tests and previews.
public final class InMemoryWalletConnectStore: WalletConnectStateStore, WalletConnectSecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: Data?
    private var secrets: Data?
    public private(set) var stateWrites = 0
    public private(set) var secretWrites = 0

    public init(state: Data? = nil, secrets: Data? = nil) {
        self.state = state
        self.secrets = secrets
    }

    public func loadState() throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func saveState(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        state = data
        stateWrites += 1
    }

    public func loadSecrets() throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return secrets
    }

    public func saveSecrets(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        secrets = data
        secretWrites += 1
    }
}
