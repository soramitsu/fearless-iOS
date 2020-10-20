import Foundation

final class StorageSubscriptionContainer: WebSocketSubscribing {
    let children: [StorageChildSubscribing]
    let engine: JSONRPCEngine
    let logger: LoggerProtocol

    private var subscriptionId: UInt16?

    init(engine: JSONRPCEngine, children: [StorageChildSubscribing], logger: LoggerProtocol) {
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
            let storageKeys = children.map { $0.storageKey.toHex(includePrefix: true) }

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
        do {
            guard let changes = update.changes else {
                return
            }

            let blockHash: Data?

            if let blockHashString = update.blockHash {
                blockHash = try Data(hexString: blockHashString)
            } else {
                blockHash = nil
            }

            for change in changes where change.count == 2 {
                guard let storageKeyString = change[0] else {
                    continue
                }

                let storageKeyData = try Data(hexString: storageKeyString)

                let childrenToNotify = children.filter { $0.storageKey == storageKeyData }

                guard !childrenToNotify.isEmpty else {
                    continue
                }

                let updateData: Data?

                if let updateDataString = change[1] {
                    updateData = try Data(hexString: updateDataString)
                } else {
                    updateData = nil
                }

                childrenToNotify.forEach { $0.processUpdate(updateData, blockHash: blockHash) }
            }
        } catch {
            logger.warning("Can't handle update: \(error)")
        }
    }
}
