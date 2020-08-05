import Foundation
import FearlessUtils

protocol StorageKeyFactoryProtocol {
    func createStorageKey(moduleName: String, serviceName: String, identifier: Data) throws -> Data
}

enum StorageKeyFactoryError: Error {
    case badSerialization
}

struct StorageKeyFactory: StorageKeyFactoryProtocol {
    func createStorageKey(moduleName: String, serviceName: String, identifier: Data) throws -> Data {
        guard let moduleKey = moduleName.data(using: .utf8) else {
            throw StorageKeyFactoryError.badSerialization
        }

        guard let serviceKey = serviceName.data(using: .utf8) else {
            throw StorageKeyFactoryError.badSerialization
        }

        let moduleKeyHash = moduleKey.xxh128()
        let serviceKeyHash = serviceKey.xxh128()

        let identifierHash = try identifier.blake128Concat()

        return moduleKeyHash + serviceKeyHash + identifierHash
    }
}
