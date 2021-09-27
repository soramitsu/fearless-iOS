import Foundation
import FearlessUtils

enum LocalStorageKeyFactoryError: Error {
    case invalidParams
}

protocol LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String
}

extension LocalStorageKeyFactoryProtocol {
    func createFromStoragePath(_ storagePath: StorageCodingPath, chainId: ChainModel.Id) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        return try createKey(from: data, chainId: chainId)
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        return try createKey(from: data + accountId, chainId: chainId)
    }
}

final class LocalStorageKeyFactory: LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String {
        let concatData = (try Data(hexString: chainId)) + remoteKey
        let localKey = try StorageHasher.twox256.hash(data: concatData)
        return localKey.toHex()
    }
}
