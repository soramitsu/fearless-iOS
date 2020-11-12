import Foundation
import Starscream

extension WebSocketEngine: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        mutex.lock()

        switch event {
        case .binary(let data):
            handleBinaryEvent(data: data)
        case .text(let string):
            handleTextEvent(string: string)
        case .connected:
            handleConnectedEvent()
        case .disconnected(let reason, let code):
            handleDisconnectedEvent(reason: reason, code: code)
        case .error(let error):
            handleErrorEvent(error)
        case .cancelled:
            handleCancelled()
        default:
            logger.warning("Unhandled event \(event)")
        }

        mutex.unlock()
    }

    private func handleCancelled() {
        logger.warning("Remote cancelled")

        switch state {
        case .connecting(let attempt):
            connection.disconnect()
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            let cancelledRequests = resetInProgress()

            pingScheduler.cancel()

            connection.disconnect()
            scheduleReconnectionOrDisconnect(1)

            notify(requests: cancelledRequests,
                   error: JSONRPCEngineError.clientCancelled)
        default:
            break
        }
    }

    private func handleErrorEvent(_ error: Error?) {
        if let error = error {
            logger.error("Did receive error: \(error)")
        } else {
            logger.error("Did receive unknown error")
        }

        switch state {
        case .connected:
            let cancelledRequests = resetInProgress()

            pingScheduler.cancel()

            connection.disconnect()
            startConnecting(0)

            notify(requests: cancelledRequests,
                   error: JSONRPCEngineError.clientCancelled)
        case .connecting(let attempt):
            connection.disconnect()

            scheduleReconnectionOrDisconnect(attempt + 1)
        default:
            break
        }
    }

    private func handleBinaryEvent(data: Data) {
        if let decodedString = String(data: data, encoding: .utf8) {
            logger.debug("Did receive data: \(decodedString)")
        }

        process(data: data)
    }

    private func handleTextEvent(string: String) {
        logger.debug("Did receive text: \(string)")
        if let data = string.data(using: .utf8) {
            process(data: data)
        } else {
            logger.warning("Unsupported text event: \(string)")
        }
    }

    private func handleConnectedEvent() {
        logger.debug("connection established")

        changeState(.connected)
        sendAllPendingRequests()

        schedulePingIfNeeded()
    }

    private func handleDisconnectedEvent(reason: String, code: UInt16) {
        logger.warning("Disconnected with code \(code): \(reason)")

        switch state {
        case .connecting(let attempt):
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            let cancelledRequests = resetInProgress()

            pingScheduler.cancel()

            scheduleReconnectionOrDisconnect(1)

            notify(requests: cancelledRequests,
                   error: JSONRPCEngineError.remoteCancelled)
        default:
            break
        }
    }
}

extension WebSocketEngine: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        mutex.lock()

        if manager.isReachable, case .waitingReconnection = state {

            logger.debug("Network became reachable, retrying connection")

            reconnectionScheduler.cancel()
            startConnecting(0)
        }

        mutex.unlock()
    }
}

extension WebSocketEngine: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        mutex.lock()

        if scheduler === pingScheduler {
            handlePing(scheduler: scheduler)
        } else {
            handleReconnection(scheduler: scheduler)
        }

        mutex.unlock()
    }

    private func handleReconnection(scheduler: SchedulerProtocol) {
        logger.debug("Did trigger reconnection scheduler")

        if case .waitingReconnection(let attempt) = state {
            startConnecting(attempt)
        }
    }

    private func handlePing(scheduler: SchedulerProtocol) {
        schedulePingIfNeeded()

        connection.callbackQueue.async {
            self.sendPing()
        }
    }
}
