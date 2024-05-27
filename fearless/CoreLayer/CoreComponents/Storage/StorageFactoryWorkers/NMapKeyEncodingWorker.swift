import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

final class NMapKeyEncodingWorker {
    private let keyParams: [[[any NMapKeyParamProtocol]]]
    private let codingFactory: RuntimeCoderFactoryProtocol
    private let path: any StorageCodingPathProtocol
    private let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        codingFactory: RuntimeCoderFactoryProtocol,
        path: any StorageCodingPathProtocol,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams: [[[any NMapKeyParamProtocol]]]
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

        let keys: [Data] = try keyParams.compactMap {
            guard keyEntries.count == $0.count else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            var params: [[any NMapKeyParamProtocol]] = []
            for index in 0 ..< $0[0].count {
                var array: [any NMapKeyParamProtocol] = []
                for param in $0 {
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
        }.reduce([], +)

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
