import Foundation
import SSFUtils
import SSFModels

enum LocalStorageKeyFactoryError: Error {
    case invalidParams
}

protocol LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, key: String) throws -> String
}

extension LocalStorageKeyFactoryProtocol {
    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        chainId: ChainModel.Id
    ) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        return try createKey(from: data, key: chainId)
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        chainAssetKey: ChainAssetKey
    ) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )
        return try createKey(
            from: data,
            key: chainAssetKey
        )
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        encodableElement: ScaleEncodable,
        chainId: ChainModel.Id
    ) throws -> String {
        let storagePathData = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        let elementData = try encodableElement.scaleEncoded()

        return try createKey(from: storagePathData + elementData, key: chainId)
    }
}

final class LocalStorageKeyFactory: LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, key: String) throws -> String {
        let concatData = Data(key.utf8) + remoteKey
        let localKey = try StorageHasher.twox256.hash(data: concatData)
        return localKey.toHex()
    }
}
