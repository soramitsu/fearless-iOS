import Foundation
import SoraFoundation
import SoraKeystore

final class WebSocketService: WebSocketServiceProtocol {
    static let shared: WebSocketService = {
        let url = SettingsManager.shared.selectedConnection.url

        return WebSocketService(url: url,
                                connectionFactory: WebSocketEngineFactory(),
                                applicationHandler: ApplicationHandler())
    }()

    enum State {
        case throttled
        case active
        case inactive
    }

    var connection: JSONRPCEngine? { engine }

    let applicationHandler: ApplicationHandlerProtocol
    let connectionFactory: WebSocketEngineFactoryProtocol

    private(set) var url: URL
    private(set) var engine: WebSocketEngine?

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    init(url: URL,
         connectionFactory: WebSocketEngineFactoryProtocol,
         applicationHandler: ApplicationHandlerProtocol) {
        self.applicationHandler = applicationHandler
        self.url = url
        self.connectionFactory = connectionFactory
    }

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        applicationHandler.delegate = self

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    func update(url: URL) {
        guard self.url != url else {
            return
        }

        self.url = url

        if !isThrottled {
            clearConnection()
            setupConnection()
        }
    }

    private func clearConnection() {
        engine?.disconnectIfNeeded()
        engine = nil
    }

    private func setupConnection() {
        engine = connectionFactory.createEngine(for: url, autoconnect: isActive)
    }
}

extension WebSocketService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification: Notification) {
        if !isThrottled, !isActive {
            isActive = true

            engine?.connectIfNeeded()
        }
    }

    func didReceiveDidEnterBackground(notification: Notification) {
        if !isThrottled, isActive {
            isActive = false

            engine?.disconnectIfNeeded()
        }
    }
}
