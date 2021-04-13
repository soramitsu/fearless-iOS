import Foundation
import RobinHood
import FearlessUtils

struct LocalStorageResponse<T: Decodable> {
    let key: String
    let data: Data?
    let value: T?
}

protocol LocalStorageRequestFactoryProtocol {
    func queryItems<K, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam: @escaping () throws -> K,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where K: Encodable, T: Decodable

    func queryItems<K1, K2, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam1: @escaping () throws -> K1,
        keyParam2: @escaping () throws -> K2,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where K1: Encodable, K2: Encodable, T: Decodable

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable
}

final class LocalStorageRequestFactory: LocalStorageRequestFactoryProtocol {
    let remoteKeyFactory: StorageKeyFactoryProtocol
    let localKeyFactory: ChainStorageIdFactoryProtocol

    init(remoteKeyFactory: StorageKeyFactoryProtocol, localKeyFactory: ChainStorageIdFactoryProtocol) {
        self.remoteKeyFactory = remoteKeyFactory
        self.localKeyFactory = localKeyFactory
    }

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable {
        do {
            let remoteKey = try remoteKeyFactory.createStorageKey(
                moduleName: params.path.moduleName,
                storageName: params.path.itemName
            )

            let localKey = localKeyFactory.createIdentifier(for: remoteKey)

            return queryItems(repository: repository, key: { localKey }, factory: factory, params: params)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable {
        let queryOperation = repository.fetchOperation(by: key, options: RepositoryFetchOptions())

        let decodingOperation = StorageDecodingListOperation<T>(path: params.path)
        decodingOperation.configurationBlock = {
            do {
                let result = try queryOperation.extractNoCancellableResultData()

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result.map { [$0.data] } ?? []
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mapOperation = ClosureOperation<LocalStorageResponse<T>> {
            let fetchResult = try queryOperation.extractNoCancellableResultData()
            let decodedResult = try decodingOperation.extractNoCancellableResultData().first
            let key = try key()

            return LocalStorageResponse(key: key, data: fetchResult?.data, value: decodedResult)
        }

        mapOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam: @escaping () throws -> K,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where K: Encodable, T: Decodable {
        let keysOperation = MapKeyEncodingOperation<K>(path: params.path, storageKeyFactory: remoteKeyFactory)

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams = [try keyParam()]
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let localWrapper = keysOperation.localWrapper(for: localKeyFactory)

        let keyClosure: () throws -> String = {
            guard let key = try localWrapper.targetOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.parentOperationCancelled
            }

            return key
        }

        let queryWrapper: CompoundOperationWrapper<LocalStorageResponse<T>> =
            queryItems(repository: repository, key: keyClosure, factory: factory, params: params)

        queryWrapper.allOperations.forEach { $0.addDependency(localWrapper.targetOperation) }

        let dependencies = localWrapper.allOperations + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K1, K2, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam1: @escaping () throws -> K1,
        keyParam2: @escaping () throws -> K2,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where K1: Encodable, K2: Encodable, T: Decodable {
        let keysOperation = DoubleMapKeyEncodingOperation<K1, K2>(
            path: params.path,
            storageKeyFactory: remoteKeyFactory
        )

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams1 = [try keyParam1()]
                keysOperation.keyParams2 = [try keyParam2()]
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let localWrapper = keysOperation.localWrapper(for: localKeyFactory)

        let keyClosure: () throws -> String = {
            guard let key = try localWrapper.targetOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.parentOperationCancelled
            }

            return key
        }

        let queryWrapper: CompoundOperationWrapper<LocalStorageResponse<T>> =
            queryItems(repository: repository, key: keyClosure, factory: factory, params: params)

        queryWrapper.allOperations.forEach { $0.addDependency(localWrapper.targetOperation) }

        let dependencies = localWrapper.allOperations + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}

extension LocalStorageRequestFactoryProtocol {
    func queryItems<K, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam: @escaping () throws -> K,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<T?> where K: Encodable, T: Decodable {
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<T>> = queryItems(
            repository: repository,
            keyParam: keyParam,
            factory: factory,
            params: params
        )

        let mapOperation = ClosureOperation<T?> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func queryItems<K1, K2, T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        keyParam1: @escaping () throws -> K1,
        keyParam2: @escaping () throws -> K2,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<T?> where K1: Encodable, K2: Encodable, T: Decodable {
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<T>> = queryItems(
            repository: repository,
            keyParam1: keyParam1,
            keyParam2: keyParam2,
            factory: factory,
            params: params
        )

        let mapOperation = ClosureOperation<T?> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<T?> where T: Decodable {
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<T>> =
            queryItems(repository: repository, key: key, factory: factory, params: params)

        let mapOperation = ClosureOperation<T?> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<T?> where T: Decodable {
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<T>> =
            queryItems(repository: repository, factory: factory, params: params)

        let mapOperation = ClosureOperation<T?> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }
}
