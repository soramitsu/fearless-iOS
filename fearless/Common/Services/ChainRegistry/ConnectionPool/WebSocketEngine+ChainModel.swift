import Foundation

extension WebSocketEngine {
    static func createFrom(chain: ChainModel, logger: LoggerProtocol) throws -> WebSocketEngine {
        guard let url = chain.nodes.first?.url else {
            throw JSONRPCEngineError.unknownError
        }

        return WebSocketEngine(url: url, logger: logger)
    }
}
