import Foundation
import FearlessUtils

final class StakingInfoSubscription: WebSocketSubscribing {
    let engine: JSONRPCEngine
    let logger: LoggerProtocol

    var controllerId: Data? {
        didSet {
            if controllerId != oldValue {
                unsubscribe()
                subscribe()
            }
        }
    }

    private var subscriptionId: UInt16?

    init(engine: JSONRPCEngine, logger: LoggerProtocol) {
        self.engine = engine
        self.logger = logger

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        do {
            guard let controllerId = controllerId else {
                return
            }

            let storageKey = try StorageKeyFactory().createStorageKey(moduleName: "Staking",
                                                                      serviceName: "Ledger",
                                                                      identifier: controllerId)
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = {
                [weak self] (update) in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] (error, unsubscribed) in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try engine.subscribe(RPCMethod.storageSubscibe,
                                                  params: [[storageKey]],
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

            guard let change = changes.first, change.count == 2 else {
                return
            }

            let updatedData: Data?

            if let updatedDataString = change[1] {
                updatedData = try Data(hexString: updatedDataString)
            } else {
                updatedData = nil
            }

            logger.debug("Did receive staking ledger update")
        } catch {
            logger.warning("Can't handle update: \(error)")
        }
    }
}
