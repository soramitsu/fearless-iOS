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
        guard let strategy = ConnectionStrategyImpl(
            urls: [url],
            callbackQueue: DispatchQueue(label: "co.jp.SubstrateOperationFactory.connection")
        ) else {
            return BaseOperation.createWithError(SubstrateOperationFactoryError.connectionUnavailable)
        }

        let engine = WebSocketEngine(
            connectionName: nil,
            connectionStrategy: strategy,
            logger: logger
        )

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
