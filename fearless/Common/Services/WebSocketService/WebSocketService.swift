import Foundation
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils

final class WebSocketService: WebSocketServiceProtocol {
    enum State {
        case throttled
        case active
        case inactive
    }

    var connection: JSONRPCEngine? { engine }

    let applicationHandler: ApplicationHandlerProtocol
    let chainRegistry: ChainRegistryProtocol

    private(set) var settings: WebSocketServiceSettings
    private(set) var engine: WebSocketEngine?

    private(set) var subscriptions: [WebSocketSubscribing]?

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    var networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol?
    private var stateListeners: [WeakWrapper] = []

    init(
        settings: WebSocketServiceSettings,
        chainRegistry: ChainRegistryProtocol,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.settings = settings
        self.applicationHandler = applicationHandler
        self.chainRegistry = chainRegistry
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

    func update(settings: WebSocketServiceSettings) {
        guard self.settings != settings else {
            return
        }

        self.settings = settings

        if !isThrottled {
            clearConnection()
            setupConnection()
        }
    }

    func addStateListener(_ listener: WebSocketServiceStateListener) {
        stateListeners.append(WeakWrapper(target: listener))
    }

    func removeStateListener(_ listener: WebSocketServiceStateListener) {
        stateListeners = stateListeners.filter { $0 !== listener }
    }

    private func clearConnection() {
        engine?.delegate = nil
        engine?.disconnectIfNeeded()
        engine = nil

        subscriptions = nil
    }

    private func setupConnection() {}
}

extension WebSocketService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        if !isThrottled, !isActive {
            isActive = true

            engine?.connectIfNeeded()
        }
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        if !isThrottled, isActive {
            isActive = false

            engine?.disconnectIfNeeded()
        }
    }
}

extension WebSocketService: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine _: WebSocketEngine,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        switch newState {
        case let .connecting(attempt):
            if attempt > 1 {
                scheduleNetworkUnreachable()

                stateListeners.forEach { listenerWeakWrapper in
                    (listenerWeakWrapper.target as? WebSocketServiceStateListener)?.websocketNetworkDown(url: settings.url)
                }
            }
        case .connected:
            scheduleNetworkReachable()
        default:
            break
        }
    }

    private func scheduleNetworkReachable() {
        DispatchQueue.main.async {
            self.networkStatusPresenter?.didDecideReachableStatusPresentation()
        }
    }

    private func scheduleNetworkUnreachable() {
        DispatchQueue.main.async {
            self.networkStatusPresenter?.didDecideUnreachableStatusPresentation()
        }
    }
}
