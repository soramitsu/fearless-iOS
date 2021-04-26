import Foundation
import RobinHood

final class AccountInfoSubscription: BaseStorageChildSubscription {
    let transactionSubscription: TransactionSubscription
    let eventCenter: EventCenterProtocol

    init(
        transactionSubscription: TransactionSubscription,
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.transactionSubscription = transactionSubscription
        self.eventCenter = eventCenter

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.debug("Did account info update")

        if case let .success(optionalChange) = result, optionalChange != nil {
            logger.debug("Did change account info")

            if let blockHash = blockHash {
                transactionSubscription.process(blockHash: blockHash)
            }

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }
}
