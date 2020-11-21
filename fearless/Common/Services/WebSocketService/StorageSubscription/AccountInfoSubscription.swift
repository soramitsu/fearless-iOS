import Foundation
import RobinHood

final class AccountInfoSubscription: BaseStorageChildSubscription {
    let transferSubscription: TransferSubscription

    init(transferSubscription: TransferSubscription,
         remoteStorageKey: Data,
         localStorageKey: String,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol,
         eventCenter: EventCenterProtocol) {
        self.transferSubscription = transferSubscription

        super.init(remoteStorageKey: remoteStorageKey,
                   localStorageKey: localStorageKey,
                   storage: storage,
                   operationManager: operationManager,
                   logger: logger,
                   eventCenter: eventCenter)
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.debug("Did account info update")

        if case .success(let optionalChange) = result, optionalChange != nil {
            logger.debug("Did change account info")

            if let blockHash = blockHash {
                transferSubscription.process(blockHash: blockHash)
            }

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }
}
