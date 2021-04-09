import Foundation
import RobinHood

final class UpgradeSubscription: BaseStorageChildSubscription {
    let eventCenter: EventCenterProtocol

    init(remoteStorageKey: Data,
         localStorageKey: String,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol,
         eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter

        super.init(remoteStorageKey: remoteStorageKey,
                   localStorageKey: localStorageKey,
                   storage: storage,
                   operationManager: operationManager,
                   logger: logger)
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.debug("Did receive upgrade info")

        if case .success(let optionalChange) = result, optionalChange != nil {
            logger.debug("Did change account info")

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }
}
