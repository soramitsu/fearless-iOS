import Foundation
import RobinHood
import SSFUtils

enum SubstrateOperationFactoryError: Error {
    case connectionUnavailable
}

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
            connectionName: nil,
            url: url,
            reconnectionStrategy: ExponentialReconnection(),
            logger: logger
        )

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
