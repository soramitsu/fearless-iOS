import Foundation
import SSFRuntimeCodingService
import SSFModels
import SSFUtils

actor MapKeyEncodingWorker {
    private let keyParams: [any Encodable]
    private let codingFactory: RuntimeCoderFactoryProtocol
    private let path: StorageCodingPath
    private let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        codingFactory: RuntimeCoderFactoryProtocol,
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams: [any Encodable]
    ) {
        self.codingFactory = codingFactory
        self.path = path
        self.keyParams = keyParams
        self.storageKeyFactory = storageKeyFactory
    }

    func performEncoding() throws -> [Data] {
        guard let entry = codingFactory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageKeyEncodingOperationError.invalidStoragePath
        }

        let keyType: String
        let hasher: StorageHasher

        switch entry.type {
        case let .map(mapEntry):
            keyType = mapEntry.key
            hasher = mapEntry.hasher
        case let .doubleMap(doubleMapEntry):
            keyType = doubleMapEntry.key1
            hasher = doubleMapEntry.hasher
        case let .nMap(nMapEntry):
            guard
                let firstKey = try nMapEntry.keys(using: codingFactory.metadata.schemaResolver).first,
                let firstHasher = nMapEntry.hashers.first
            else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            keyType = firstKey
            hasher = firstHasher
        case .plain:
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }

        let keys: [Data] = try keyParams.map { keyParam in
            let encoder = codingFactory.createEncoder()
            try encoder.append(keyParam, ofType: keyType)

            let encodedParam = try encoder.encode()

            return try storageKeyFactory.createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName,
                key: encodedParam,
                hasher: hasher
            )
        }
        return keys
    }
}
