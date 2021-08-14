import Foundation

protocol SpecVersionSubscriptionProtocol: AnyObject {
    func subscribe()
    func unsubscribe()
}

final class SpecVersionSubscription {
    let chainId: ChainModel.Id
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?

    private(set) var subscriptionId: UInt16?

    init(
        chainId: ChainModel.Id,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        connection: JSONRPCEngine,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.runtimeSyncService = runtimeSyncService
        self.connection = connection
        self.logger = logger
    }
}

extension SpecVersionSubscription: SpecVersionSubscriptionProtocol {
    func subscribe() {
        do {
            let updateClosure: (RuntimeVersionUpdate) -> Void = { [weak self] update in
                guard let strongSelf = self else {
                    return
                }

                let runtimeVersion = update.params.result
                strongSelf.logger?.debug("Did receive spec version: \(runtimeVersion.specVersion)")
                strongSelf.logger?.debug("Did receive tx version: \(runtimeVersion.transactionVersion)")

                strongSelf.runtimeSyncService.apply(
                    version: runtimeVersion,
                    for: strongSelf.chainId
                )
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let params: [String] = []
            subscriptionId = try connection.subscribe(
                RPCMethod.runtimeVersionSubscribe,
                params: params,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger?.error("Can't subscribe to storage: \(error)")
        }
    }

    func unsubscribe() {
        if let identifier = subscriptionId {
            subscriptionId = nil
            connection.cancelForIdentifier(identifier)
        }
    }
}
