import Foundation
import SSFUtils

extension StorageKeyFactoryProtocol {
    func accountPoolsKeyForId(_ identifier: Data, baseAssetId: Data) throws -> Data {
        let codingPath = StorageCodingPath.userPools
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key1: identifier,
            hasher1: .identity,
            key2: baseAssetId,
            hasher2: .blake128Concat
        )
    }

    func poolReservesKey(asset: Data) throws -> Data {
        let codingPath = StorageCodingPath.poolReserves
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key: asset,
            hasher: .blake128Concat
        )
    }

    func poolReservesKey(baseAssetId: Data, targetAssetId: Data) throws -> Data {
        let codingPath = StorageCodingPath.poolReserves
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key1: baseAssetId,
            hasher1: .blake128Concat,
            key2: targetAssetId,
            hasher2: .blake128Concat
        )
    }

    func xykPoolKeyProperties(asset: Data) throws -> Data {
        let codingPath = StorageCodingPath.poolProperties
        return try createStorageKey(
            moduleName: codingPath.moduleName,
            storageName: codingPath.itemName,
            key: asset,
            hasher: .blake128Concat
        )
    }

    func key(from codingPath: StorageCodingPath) throws -> Data {
        try createStorageKey(moduleName: codingPath.moduleName, storageName: codingPath.itemName)
    }
}
