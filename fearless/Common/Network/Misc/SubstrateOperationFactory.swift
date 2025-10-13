import Foundation
import RobinHood
import SSFUtils

protocol SubstrateOperationFactoryProtocol: AnyObject {
    func fetchChainOperation(_ url: URL) -> BaseOperation<String>
}

final class SubstrateOperationFactory: SubstrateOperationFactoryProtocol {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }

    func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        // SSFUtils WebSocketEngine now takes a single URL and reconnection strategy
        let engine = WebSocketEngine(
            connectionName: nil,
            url: url,
            autoconnect: false,
            logger: logger
        )

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
