import Foundation
import WalletConnectRelay

final class WalletConnectSocketFactory: WebSocketFactory {
    private lazy var logger: LoggerProtocol = {
        Logger.shared
    }()

    func create(with url: URL) -> WalletConnectRelay.WebSocketConnecting {
        var request = URLRequest(url: url)
//        request.addValue("allowed.domain.com", forHTTPHeaderField: "Origin")
        let connection = WalletConnectSocketEngine(
            request: request,
            logger: logger
        )
        return connection
    }
}
