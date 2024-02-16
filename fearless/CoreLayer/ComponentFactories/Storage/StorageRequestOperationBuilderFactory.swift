import Foundation
import SSFUtils

protocol StorageRequestOperationBuilderFactory {
    func buildStorageRequestOperationBuilder(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: StorageRequestFactoryProtocol,
        request: some StorageRequest
    ) -> StorageRequestOperationBuilder
}

final class BaseStorageRequestOperationBuilderFactory<T: Decodable>: StorageRequestOperationBuilderFactory {
    func buildStorageRequestOperationBuilder(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: StorageRequestFactoryProtocol,
        request: some StorageRequest
    ) -> StorageRequestOperationBuilder {
        switch request.parametersType {
        case .nMap:
            return NMapStorageRequestOperationBuilder<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .encodable:
            return EncodableStorageRequestOperationBuilder<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        case .keys:
            return KeysStorageRequestOperationBuilder<T>(
                runtimeService: runtimeService,
                connection: connection,
                storageRequestFactory: storageRequestFactory
            )
        }
    }
}
