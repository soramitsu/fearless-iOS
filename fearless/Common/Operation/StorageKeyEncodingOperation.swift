import Foundation
import FearlessUtils
import RobinHood

enum StorageKeyEncodingOperationError: Error {
    case missingRequiredParams
    case incompatibleStorageType
    case invalidStoragePath
}

class MapKeyEncodingOperation<T: Encodable>: BaseOperation<[Data]> {
    var keyParams: [T]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(path: StorageCodingPath, storageKeyFactory: StorageKeyFactoryProtocol, keyParams: [T]? = nil) {
        self.path = path
        self.keyParams = keyParams
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let factory = codingFactory, let keyParams = keyParams else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
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
                    let firstKey = nMapEntry.keyVec.first,
                    let firstHasher = nMapEntry.hashers.first else {
                    throw StorageKeyEncodingOperationError.missingRequiredParams
                }

                keyType = firstKey
                hasher = firstHasher
            case .plain:
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            let keys: [Data] = try keyParams.map { keyParam in
                let encoder = factory.createEncoder()
                try encoder.append(keyParam, ofType: keyType)

                let encodedParam = try encoder.encode()

                return try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName,
                    key: encodedParam,
                    hasher: hasher
                )
            }

            result = .success(keys)
        } catch {
            result = .failure(error)
        }
    }
}

class DoubleMapKeyEncodingOperation<T1: Encodable, T2: Encodable>: BaseOperation<[Data]> {
    var keyParams1: [T1]?
    var keyParams2: [T2]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams1: [T1]? = nil,
        keyParams2: [T2]? = nil
    ) {
        self.path = path
        self.keyParams1 = keyParams1
        self.keyParams2 = keyParams2
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let factory = codingFactory,
                  let keyParams1 = keyParams1,
                  let keyParams2 = keyParams2,
                  keyParams1.count == keyParams2.count
            else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            guard case let .doubleMap(doubleMapEntry) = entry.type else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            let keys: [Data] = try zip(keyParams1, keyParams2).map { param in
                let encodedParam1 = try encodeParam(
                    param.0,
                    factory: factory,
                    type: doubleMapEntry.key1
                )

                let encodedParam2 = try encodeParam(
                    param.1,
                    factory: factory,
                    type: doubleMapEntry.key2
                )

                return try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName,
                    key1: encodedParam1,
                    hasher1: doubleMapEntry.hasher,
                    key2: encodedParam2,
                    hasher2: doubleMapEntry.key2Hasher
                )
            }

            result = .success(keys)
        } catch {
            result = .failure(error)
        }
    }

    private func encodeParam<T: Encodable>(
        _ param: T,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        let encoder = factory.createEncoder()
        try encoder.append(param, ofType: type)
        return try encoder.encode()
    }
}

extension MapKeyEncodingOperation {
    func localWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        baseLocalWrapper(for: factory)
    }
}

extension DoubleMapKeyEncodingOperation {
    func localWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        baseLocalWrapper(for: factory)
    }
}

private extension BaseOperation where ResultType == [Data] {
    func baseLocalWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        let mapOperation = ClosureOperation<[String]> {
            let keys = try self.extractNoCancellableResultData()
            return keys.map { factory.createIdentifier(for: $0) }
        }

        mapOperation.addDependency(self)
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [self])
    }
}
