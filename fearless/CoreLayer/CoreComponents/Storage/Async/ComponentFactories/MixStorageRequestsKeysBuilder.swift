import Foundation
import SSFRuntimeCodingService
import SSFUtils

final class MixStorageRequestsKeysBuilder {
    private lazy var storageKeyFactory: StorageKeyFactoryProtocol = StorageKeyFactory()

    private let codingFactory: RuntimeCoderFactoryProtocol

    init(codingFactory: RuntimeCoderFactoryProtocol) {
        self.codingFactory = codingFactory
    }

    func buildKeys(for request: [any MixStorageRequest]) throws -> [Data] {
        let keys = try request.map { request in
            switch request.parametersType {
            case let .nMap(params):
                let keysWorker = NMapKeyEncodingWorker(
                    codingFactory: codingFactory,
                    path: request.storagePath,
                    storageKeyFactory: storageKeyFactory,
                    keyParams: [params]
                )
                let keys = try keysWorker.performEncoding()
                return keys

            case let .encodable(params):
                let keysWorker = MapKeyEncodingWorker(
                    codingFactory: codingFactory,
                    path: request.storagePath,
                    storageKeyFactory: storageKeyFactory,
                    keyParams: [params]
                )
                let keys = try keysWorker.performEncoding()
                return keys

            case .simple:
                let key = try storageKeyFactory.createStorageKey(
                    moduleName: request.storagePath.moduleName,
                    storageName: request.storagePath.itemName
                )
                return [key]
            }
        }

        return keys.reduce([], +)
    }
}
