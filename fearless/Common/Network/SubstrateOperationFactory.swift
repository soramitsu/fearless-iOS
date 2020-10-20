import Foundation
import RobinHood

protocol SubstrateOperationFactoryProtocol: class {
    func fetchChainOperation(_ url: URL) -> BaseOperation<String>
}

final class SubstrateOperationFactory: SubstrateOperationFactoryProtocol {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        let engine = WebSocketEngine(url: url,
                                     reachabilityManager: nil,
                                     reconnectionStrategy: nil,
                                     logger: logger)

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
