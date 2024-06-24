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
        guard let engine = try? WebSocketEngine(
            connectionName: nil,
            urls: [url],
            reachabilityManager: nil,
            reconnectionStrategy: nil,
            logger: nil
        ) else {
            return BaseOperation.createWithError(WebSocketEngineError.emptyUrls)
        }

        return JSONRPCListOperation(engine: engine, method: RPCMethod.chain)
    }
}
