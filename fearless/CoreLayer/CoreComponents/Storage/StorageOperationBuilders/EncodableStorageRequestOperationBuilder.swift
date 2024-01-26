import Foundation
import SSFUtils
import RobinHood

class EncodableStorageRequestOperationBuilder<P: Decodable>: StorageRequestOperationBuilder {
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.runtimeService = runtimeService
        self.connection = connection
        self.storageRequestFactory = storageRequestFactory
    }

    func createStorageRequestOperation<T: Decodable>(
        request: some StorageRequest
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        guard case let StorageRequestParametersType.encodable(params: params) = request.parametersType else {
            return CompoundOperationWrapper.createWithError(NMapStorageRequestOperationBuilderError.invalidParameters)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<T>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: params,
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: request.storagePath
        )

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let deps = wrapper.dependencies + [coderFactoryOperation]

        return CompoundOperationWrapper(targetOperation: wrapper.targetOperation, dependencies: deps)
    }
}
