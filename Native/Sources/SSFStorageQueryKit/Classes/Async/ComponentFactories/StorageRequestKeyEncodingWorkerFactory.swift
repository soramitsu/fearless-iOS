import Foundation
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

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
        case .encodable(let params):
            return MapKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory,
                keyParams: params
            )
        case .nMap(let params):
            return NMapKeyEncodingWorker(
                codingFactory: codingFactory,
                path: storageCodingPath,
                storageKeyFactory: storageKeyFactory,
                keyParams: params
            )
        case .prefixEncodable(let params):
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
