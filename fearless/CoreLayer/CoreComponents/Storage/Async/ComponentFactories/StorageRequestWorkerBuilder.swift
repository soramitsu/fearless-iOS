import Foundation
import SSFRuntimeCodingService
import SSFUtils

protocol StorageRequestWorkerBuilder {
    func buildWorker(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: AsyncStorageRequestFactory,
        type: StorageRequestWorkerType
    ) -> StorageRequestWorker
}

public enum StorageRequestWorkerType {
    case nMap(params: [[[any NMapKeyParamProtocol]]])
    case encodable(params: [any Encodable])
    case simple
    case prefix
    case prefixEncodable(params: [any Encodable])
}

final class StorageRequestWorkerBuilderDefault<T: Decodable>: StorageRequestWorkerBuilder {
    func buildWorker(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: AsyncStorageRequestFactory,
        type: StorageRequestWorkerType
    ) -> StorageRequestWorker {
        switch type {
        case .nMap:
            return NMapStorageRequestWorker<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .encodable:
            return EncodableStorageRequestWorker<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .simple:
            return SimpleStorageRequestWorker<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .prefix:
            return PrefixStorageRequestWorker<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .prefixEncodable:
            return PrefixEncodableStorageRequestWorker<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        }
    }
}
