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
        let engine = WebSocketEngine(url: url, logger: logger)
        return JSONRPCOperation(engine: engine, method: RPCMethod.chain, parameters: [])
    }
}
