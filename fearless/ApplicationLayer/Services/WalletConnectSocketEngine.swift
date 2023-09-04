import Foundation
import WalletConnectRelay
import Starscream

final class WalletConnectSocketEngine: WebSocketConnecting {
    public var request: URLRequest
    public var isConnected: Bool = false
    public var onConnect: (() -> Void)?
    public var onDisconnect: ((Error?) -> Void)?
    public var onText: ((String) -> Void)?

    private var webSocket: WebSocket?
    private let logger: LoggerProtocol

    init(
        request: URLRequest,
        logger: LoggerProtocol
    ) {
        self.request = request
        self.logger = logger
    }

    func connect() {
        logger.debug("will start connecting")

        forceDisconnect()
        connectAndListenEvent()
    }

    func disconnect() {
        isConnected = false

        logger.debug("will force disconnect")

        forceDisconnect()
    }

    func write(string: String, completion: (() -> Void)?) {
        webSocket?.write(string: string, completion: completion)
    }

    private func connectAndListenEvent() {
        let engine = WSEngine(
            transport: TCPTransport(),
            certPinner: FoundationSecurity()
        )
        webSocket = WebSocket(request: request, engine: engine)

        webSocket?.onEvent = { [weak self] event in
            self?.logger.debug("Did receive event: \(event)")

            switch event {
            case .connected:
                self?.didConnected()
            case let .disconnected(message, code):
                self?.didDisconnectedWith(
                    error: ConvenienceError(error: "message: \(message), code: \(code)")
                )
            case .cancelled:
                self?.didDisconnectedWith(error: ConvenienceError(error: "cancelled"))
            case .reconnectSuggested:
                self?.softReconnect()
            case let .viabilityChanged(isViable):
                break
//                if isViable {
//                    self?.softReconnect()
//                } else {
//                    self?.didDisconnectedWith(error: ConvenienceError(error: "Not viable"))
//                }
            case let .error(error):
                self?.didDisconnectedWith(error: error)
            case let .text(text):
                self?.onText?(text)
            case .ping, .pong, .binary:
                break
            }
        }

        webSocket?.connect()
    }

    private func forceDisconnect() {
        webSocket?.onEvent = nil
        webSocket?.forceDisconnect()
        webSocket = nil
    }

    private func softReconnect() {
        forceDisconnect()
        connectAndListenEvent()
    }

    private func didConnected() {
        isConnected = true
        onConnect?()
    }

    private func didDisconnectedWith(error: Error?) {
        isConnected = false
        forceDisconnect()
        onDisconnect?(error)
    }
}
