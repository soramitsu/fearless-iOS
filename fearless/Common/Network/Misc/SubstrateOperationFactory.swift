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
        guard let connectionStrategy = ConnectionStrategyImpl(
            urls: [url],
            callbackQueue: .global()
        ) else {
            return BaseOperation.createWithError(WebSocketEngineError.emptyUrls)
        }
        let engine = WebSocketEngine(
            connectionName: nil,
            connectionStrategy: connectionStrategy
        )

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
