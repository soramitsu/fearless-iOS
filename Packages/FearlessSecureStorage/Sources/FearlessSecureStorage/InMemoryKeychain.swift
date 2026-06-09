import Foundation

public final class InMemoryKeychain: KeystoreProtocol {
    private var keys: [String: Data]

    public init(keys: [String: Data] = [:]) {
        self.keys = keys
    }

    public func addKey(_ key: Data, with identifier: String) throws {
        if keys[identifier] != nil {
            throw KeystoreError.duplicatedItem
        }

        keys[identifier] = key
    }

    public func updateKey(_ key: Data, with identifier: String) throws {
        guard keys[identifier] != nil else {
            throw KeystoreError.noKeyFound
        }

        keys[identifier] = key
    }

    public func fetchKey(for identifier: String) throws -> Data {
        guard let key = keys[identifier] else {
            throw KeystoreError.noKeyFound
        }

        return key
    }

    public func checkKey(for identifier: String) throws -> Bool {
        keys[identifier] != nil
    }

    public func deleteKey(for identifier: String) throws {
        guard keys.removeValue(forKey: identifier) != nil else {
            throw KeystoreError.noKeyFound
        }
    }
}
