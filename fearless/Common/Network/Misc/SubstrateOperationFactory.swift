import Foundation
import RobinHood
import FearlessUtils

protocol SubstrateOperationFactoryProtocol: AnyObject {
    func fetchChainOperation(_ url: URL) -> BaseOperation<String>
}

final class SubstrateOperationFactory: SubstrateOperationFactoryProtocol {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }

    func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        let engine = WebSocketEngine(
            url: url,
            reachabilityManager: nil,
            reconnectionStrategy: nil,
            logger: logger
        )

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
