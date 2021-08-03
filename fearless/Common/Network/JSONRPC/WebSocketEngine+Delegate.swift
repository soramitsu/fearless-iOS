import Foundation
import Starscream

extension WebSocketEngine: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client _: WebSocket) {
        mutex.lock()

        switch event {
        case let .binary(data):
            handleBinaryEvent(data: data)
        case let .text(string):
            handleTextEvent(string: string)
        case .connected:
            handleConnectedEvent()
        case let .disconnected(reason, code):
            handleDisconnectedEvent(reason: reason, code: code)
        case let .error(error):
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
        case let .connecting(attempt):
            connection.disconnect()
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            let cancelledRequests = resetInProgress()

            pingScheduler.cancel()

            connection.disconnect()
            scheduleReconnectionOrDisconnect(1)

            notify(
                requests: cancelledRequests,
                error: JSONRPCEngineError.clientCancelled
            )
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

            notify(
                requests: cancelledRequests,
                error: JSONRPCEngineError.clientCancelled
            )
        case let .connecting(attempt):
            connection.disconnect()

            scheduleReconnectionOrDisconnect(attempt + 1)
        default:
            break
        }
    }

    private func handleBinaryEvent(data: Data) {
        if let decodedString = String(data: data, encoding: .utf8) {
            logger.debug("Did receive data: \(decodedString.prefix(1024))")
        }

        process(data: data)
    }

    private func handleTextEvent(string: String) {
        logger.debug("Did receive text: \(string.prefix(1024))")
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
        case let .connecting(attempt):
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            let cancelledRequests = resetInProgress()

            pingScheduler.cancel()

            scheduleReconnectionOrDisconnect(1)

            notify(
                requests: cancelledRequests,
                error: JSONRPCEngineError.remoteCancelled
            )
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

    private func handleReconnection(scheduler _: SchedulerProtocol) {
        logger.debug("Did trigger reconnection scheduler")

        if case let .waitingReconnection(attempt) = state {
            startConnecting(attempt)
        }
    }

    private func handlePing(scheduler _: SchedulerProtocol) {
        schedulePingIfNeeded()

        connection.callbackQueue.async {
            self.sendPing()
        }
    }
}
