import Foundation
import RobinHood

final class StorageSubscriptionContainer: WebSocketSubscribing {
    let children: [StorageChildSubscribing]
    let engine: JSONRPCEngine
    let logger: LoggerProtocol

    private var subscriptionId: UInt16?

    init(engine: JSONRPCEngine,
         children: [StorageChildSubscribing],
         logger: LoggerProtocol) {
        self.children = children
        self.engine = engine
        self.logger = logger

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        do {
            let storageKeys = children.map { $0.remoteStorageKey.toHex(includePrefix: true) }

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = {
                [weak self] (update) in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] (error, unsubscribed) in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try engine.subscribe(RPCMethod.storageSubscibe,
                                                  params: [storageKeys],
                                                  updateClosure: updateClosure,
                                                  failureClosure: failureClosure)
        } catch {
            logger.error("Can't subscribe to storage: \(error)")
        }
    }

    private func unsubscribe() {
        if let identifier = subscriptionId {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        let updateData = StorageUpdateData(update: update)

        for change in updateData.changes {
            let childrenToNotify = children.filter { $0.remoteStorageKey == change.key }

            childrenToNotify.forEach {
                $0.processUpdate(change.value, blockHash: updateData.blockHash)
            }
        }
    }
}
