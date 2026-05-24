import Foundation

public enum KeystoreError: Error, Equatable {
    case invalidIdentifierFormat
    case noKeyFound
    case duplicatedItem
    case unexpectedFail
}

public protocol KeystoreProtocol: AnyObject {
    func addKey(_ key: Data, with identifier: String) throws
    func updateKey(_ key: Data, with identifier: String) throws
    func fetchKey(for identifier: String) throws -> Data
    func checkKey(for identifier: String) throws -> Bool
    func deleteKey(for identifier: String) throws
}

public extension KeystoreProtocol {
    func saveKey(_ key: Data, with identifier: String) throws {
        if try checkKey(for: identifier) {
            try updateKey(key, with: identifier)
        } else {
            try addKey(key, with: identifier)
        }
    }

    func deleteKeyIfExists(for identifier: String) throws {
        if try checkKey(for: identifier) {
            try deleteKey(for: identifier)
        }
    }

    func deleteKeysIfExist(for identifiers: [String]) throws {
        for identifier in identifiers {
            try deleteKeyIfExists(for: identifier)
        }
    }
}

public protocol SecretDataRepresentable {
    func asSecretData() -> Data?
}

public extension SecretDataRepresentable {
    func toUTF8String() -> String? {
        guard let data = asSecretData() else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

extension String: SecretDataRepresentable {
    public func asSecretData() -> Data? {
        data(using: .utf8)
    }
}

extension Data: SecretDataRepresentable {
    public func asSecretData() -> Data? {
        self
    }
}

public protocol SecretStoreManagerProtocol: AnyObject {
    func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    )

    func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func checkSecret(for identifier: String) -> Bool
}
