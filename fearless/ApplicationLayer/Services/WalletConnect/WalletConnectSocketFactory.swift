import Foundation
import WalletConnectRelay

final class WalletConnectSocketFactory: WebSocketFactory {
    private lazy var logger: LoggerProtocol = {
        Logger.shared
    }()

    func create(with url: URL) -> WalletConnectRelay.WebSocketConnecting {
        WalletConnectSocketEngine(
            request: URLRequest(url: url),
            logger: logger
        )
    }
}
