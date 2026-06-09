import Foundation
import Security

public final class Keychain: KeystoreProtocol {
    public struct Configuration: Equatable {
        public let service: String
        public let accessible: CFString

        public init(
            service: String = "jp.co.soramitsu.fearless.secure-storage",
            accessible: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ) {
            self.service = service
            self.accessible = accessible
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func addKey(_ key: Data, with identifier: String) throws {
        let attributes = try itemAttributes(for: identifier, value: key)
        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status == errSecDuplicateItem {
            throw KeystoreError.duplicatedItem
        }

        try map(status: status)
    }

    public func updateKey(_ key: Data, with identifier: String) throws {
        if !(try checkKey(for: identifier)) {
            throw KeystoreError.noKeyFound
        }

        let query = try itemQuery(for: identifier)
        let attributes = [kSecValueData as String: key]
        try map(status: SecItemUpdate(query as CFDictionary, attributes as CFDictionary))
    }

    public func fetchKey(for identifier: String) throws -> Data {
        do {
            return try fetchCurrentKey(for: identifier)
        } catch KeystoreError.noKeyFound {
            return try migrateLegacyKeyIfNeeded(for: identifier)
        }
    }

    public func checkKey(for identifier: String) throws -> Bool {
        do {
            _ = try fetchCurrentKey(for: identifier)
            return true
        } catch KeystoreError.noKeyFound {
            do {
                _ = try migrateLegacyKeyIfNeeded(for: identifier)
                return true
            } catch KeystoreError.noKeyFound {
                return false
            }
        }
    }

    public func deleteKey(for identifier: String) throws {
        let query = try itemQuery(for: identifier)
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            let legacyQuery = try legacyItemQuery(for: identifier)
            let legacyStatus = SecItemDelete(legacyQuery as CFDictionary)

            if legacyStatus == errSecItemNotFound {
                throw KeystoreError.noKeyFound
            }

            try map(status: legacyStatus)
            return
        }

        try map(status: status)

        if let legacyQuery = try? legacyItemQuery(for: identifier) {
            SecItemDelete(legacyQuery as CFDictionary)
        }
    }
}

private extension Keychain {
    func fetchCurrentKey(for identifier: String) throws -> Data {
        var query = try itemQuery(for: identifier)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        try map(status: status)

        guard let data = item as? Data else {
            throw KeystoreError.unexpectedFail
        }

        return data
    }

    func migrateLegacyKeyIfNeeded(for identifier: String) throws -> Data {
        let legacyData = try fetchLegacyKey(for: identifier)

        do {
            try addKey(legacyData, with: identifier)
        } catch KeystoreError.duplicatedItem {
            try updateKey(legacyData, with: identifier)
        }

        guard try fetchCurrentKey(for: identifier) == legacyData else {
            throw KeystoreError.unexpectedFail
        }

        let legacyQuery = try legacyItemQuery(for: identifier)
        try map(status: SecItemDelete(legacyQuery as CFDictionary))

        return legacyData
    }

    func fetchLegacyKey(for identifier: String) throws -> Data {
        var query = try legacyItemQuery(for: identifier)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        try map(status: status)

        guard let data = item as? Data else {
            throw KeystoreError.unexpectedFail
        }

        return data
    }

    func itemAttributes(for identifier: String, value: Data) throws -> [String: Any] {
        var attributes = try itemQuery(for: identifier)
        attributes[kSecAttrAccessible as String] = configuration.accessible
        attributes[kSecValueData as String] = value
        return attributes
    }

    func itemQuery(for identifier: String) throws -> [String: Any] {
        guard !identifier.isEmpty else {
            throw KeystoreError.invalidIdentifierFormat
        }

        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.service,
            kSecAttrAccount as String: identifier
        ]
    }

    func legacyItemQuery(for identifier: String) throws -> [String: Any] {
        guard let applicationTag = identifier.data(using: .utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        return [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag
        ]
    }

    func map(status: OSStatus) throws {
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            throw KeystoreError.noKeyFound
        case errSecDuplicateItem:
            throw KeystoreError.duplicatedItem
        default:
            throw KeystoreError.unexpectedFail
        }
    }
}
