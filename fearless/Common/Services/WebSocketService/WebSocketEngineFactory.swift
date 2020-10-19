import Foundation

protocol WebSocketEngineFactoryProtocol {
    func createEngine(for url: URL, autoconnect: Bool) -> WebSocketEngine
}

final class WebSocketEngineFactory: WebSocketEngineFactoryProtocol {
    func createEngine(for url: URL, autoconnect: Bool) -> WebSocketEngine {
        WebSocketEngine(url: url,
                        reachabilityManager: ReachabilityManager.shared,
                        autoconnect: autoconnect, logger: Logger.shared)
    }
}
