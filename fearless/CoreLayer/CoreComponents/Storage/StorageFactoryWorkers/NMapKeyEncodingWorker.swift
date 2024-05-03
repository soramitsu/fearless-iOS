import Foundation
import SSFRuntimeCodingService
import SSFModels
import SSFUtils

actor NMapKeyEncodingWorker {
    private let keyParams: [[any NMapKeyParamProtocol]]
    private let codingFactory: RuntimeCoderFactoryProtocol
    private let path: StorageCodingPath
    private let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        codingFactory: RuntimeCoderFactoryProtocol,
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams: [[any NMapKeyParamProtocol]]
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

        guard case let .nMap(nMapEntry) = entry.type else {
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }

        let keyEntries = try nMapEntry.keys(using: codingFactory.metadata.schemaResolver)
        guard keyEntries.count == keyParams.count else {
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }

        var params: [[any NMapKeyParamProtocol]] = []
        for index in 0 ..< keyParams[0].count {
            var array: [any NMapKeyParamProtocol] = []
            for param in keyParams {
                array.append(param[index])
            }
            params.append(array)
        }

        let keys: [Data] = try params.map { params in
            let encodedParams: [Data] = try params.enumerated().map { index, param in
                try param.encode(encoder: codingFactory.createEncoder(), type: keyEntries[index])
            }

            return try storageKeyFactory.createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName,
                keys: encodedParams,
                hashers: nMapEntry.hashers
            )
        }
        return keys
    }

    private func encodeParam(
        _ param: any NMapKeyParamProtocol,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        try param.encode(encoder: factory.createEncoder(), type: type)
    }
}
