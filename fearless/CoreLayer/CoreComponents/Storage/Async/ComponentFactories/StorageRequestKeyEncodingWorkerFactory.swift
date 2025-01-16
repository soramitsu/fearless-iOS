import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

protocol StorageRequestKeyEncodingWorkerFactory {
    func buildFactory(
        storageCodingPath: any StorageCodingPathProtocol,
        workerType: StorageRequestWorkerType,
        codingFactory: RuntimeCoderFactoryProtocol,
        storageKeyFactory: StorageKeyFactoryProtocol
    ) -> StorageKeyEncoder
}

final class StorageRequestKeyEncodingWorkerFactoryDefault: StorageRequestKeyEncodingWorkerFactory {
    func buildFactory(
        storageCodingPath: any StorageCodingPathProtocol,
        workerType: StorageRequestWorkerType,
        codingFactory: RuntimeCoderFactoryProtocol,
        storageKeyFactory: StorageKeyFactoryProtocol
    ) -> StorageKeyEncoder {
        switch workerType {
        case let .encodable(params):
            return MapKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory,
                keyParams: params
            )
        case let .nMap(params):
            return NMapKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory,
                keyParams: params
            )
        case let .prefixEncodable(params):
            return MapKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory,
                keyParams: params
            )
        case .simple, .prefix:
            return SimpleKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory
            )
        }
    }
}
