import Foundation
import SSFUtils

extension StorageKeyFactoryProtocol {
    func activeEra() throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "ActiveEra"
        )
    }

    func currentEra() throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "CurrentEra"
        )
    }

    func key(from codingPath: StorageCodingPath) throws -> Data {
        try createStorageKey(moduleName: codingPath.moduleName, storageName: codingPath.itemName)
    }
}
