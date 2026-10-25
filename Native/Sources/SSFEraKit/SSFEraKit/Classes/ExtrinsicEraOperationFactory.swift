import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

public struct ExtrinsicEraParameters {
    public let blockNumber: BlockNumber
    public let extrinsicEra: Era
}

public protocol ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters>
}
