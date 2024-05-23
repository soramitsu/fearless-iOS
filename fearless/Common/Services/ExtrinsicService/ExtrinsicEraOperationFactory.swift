import Foundation
import RobinHood
import SSFUtils
import SSFRuntimeCodingService

struct ExtrinsicEraParameters {
    let blockNumber: BlockNumber
    let extrinsicEra: Era
}

protocol ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters>
}
