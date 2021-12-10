import Foundation
import RobinHood
import FearlessUtils

protocol SubscriptionRequestProtocol {
    var localKey: String { get }
    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data>
}

struct UnkeyedSubscriptionRequest: SubscriptionRequestProtocol {
    let storagePath: StorageCodingPath
    let localKey: String

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let operation = UnkeyedEncodingOperation(path: storagePath, storageKeyFactory: storageKeyFactory)
        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryClosure()
            } catch {
                operation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

struct MapSubscriptionRequest<T: Encodable>: SubscriptionRequestProtocol {
    let storagePath: StorageCodingPath
    let localKey: String
    let keyParamClosure: () throws -> T

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let encodingOperation = MapKeyEncodingOperation<T>(path: storagePath, storageKeyFactory: storageKeyFactory)
        encodingOperation.configurationBlock = {
            do {
                let keyParam = try keyParamClosure()
                encodingOperation.keyParams = [keyParam]

                encodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<Data> {
            guard let remoteKey = try encodingOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return remoteKey
        }

        mappingOperation.addDependency(encodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [encodingOperation])
    }
}

struct DoubleMapSubscriptionRequest<T1: Encodable, T2: Encodable>: SubscriptionRequestProtocol {
    let storagePath: StorageCodingPath
    let localKey: String
    let keyParamClosure: () throws -> (T1, T2)

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let encodingOperation = DoubleMapKeyEncodingOperation<T1, T2>(
            path: storagePath,
            storageKeyFactory: storageKeyFactory
        )

        encodingOperation.configurationBlock = {
            do {
                let keyParams = try keyParamClosure()
                encodingOperation.keyParams1 = [keyParams.0]
                encodingOperation.keyParams2 = [keyParams.1]

                encodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<Data> {
            guard let remoteKey = try encodingOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return remoteKey
        }

        mappingOperation.addDependency(encodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [encodingOperation])
    }
}
