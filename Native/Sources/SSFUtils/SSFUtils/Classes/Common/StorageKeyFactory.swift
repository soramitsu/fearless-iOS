import Foundation

public protocol StorageKeyFactoryProtocol: AnyObject {
    func createStorageKey(moduleName: String, storageName: String) throws -> Data

    func createStorageKey(
        moduleName: String,
        storageName: String,
        key: Data,
        hasher: StorageHasher
    ) throws -> Data

    func createStorageKey(
        moduleName: String,
        storageName: String,
        key1: Data,
        hasher1: StorageHasher,
        key2: Data,
        hasher2: StorageHasher
    ) throws -> Data

    func createStorageKey(
        moduleName: String,
        storageName: String,
        keys: [Data],
        hashers: [StorageHasher]
    ) throws -> Data
}

public enum StorageKeyFactoryError: Error {
    case badSerialization
}

public final class StorageKeyFactory: StorageKeyFactoryProtocol {
    public init() {}

    public func createStorageKey(moduleName: String, storageName: String) throws -> Data {
        guard let moduleKey = moduleName.data(using: .utf8) else {
            throw StorageKeyFactoryError.badSerialization
        }

        guard let serviceKey = storageName.data(using: .utf8) else {
            throw StorageKeyFactoryError.badSerialization
        }

        return moduleKey.twox128() + serviceKey.twox128()
    }

    public func createStorageKey(
        moduleName: String,
        storageName: String,
        key: Data,
        hasher: StorageHasher
    ) throws -> Data {
        try createStorageKey(
            moduleName: moduleName,
            storageName: storageName,
            keys: [key],
            hashers: [hasher]
        )
    }

    public func createStorageKey(
        moduleName: String,
        storageName: String,
        key1: Data,
        hasher1: StorageHasher,
        key2: Data,
        hasher2: StorageHasher
    ) throws -> Data {
        try createStorageKey(
            moduleName: moduleName,
            storageName: storageName,
            keys: [key1, key2],
            hashers: [hasher1, hasher2]
        )
    }

    public func createStorageKey(
        moduleName: String,
        storageName: String,
        keys: [Data],
        hashers: [StorageHasher]
    ) throws -> Data {
        guard !keys.isEmpty, !hashers.isEmpty, keys.count == hashers.count else {
            throw StorageKeyFactoryError.badSerialization
        }

        var data = try createStorageKey(moduleName: moduleName, storageName: storageName)
        for (index, key) in keys.enumerated() {
            let hasher = hashers[index]
            let hash = try hasher.hash(data: key)
            data += hash
        }

        return data
    }
}
