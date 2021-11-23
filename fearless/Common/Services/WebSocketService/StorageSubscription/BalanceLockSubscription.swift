import Foundation
import RobinHood

final class BalanceLockSubscription: BaseStorageChildSubscription {
    let eventCenter: EventCenterProtocol

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.eventCenter = eventCenter

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash _: Data?) {
        logger.debug("Did balance locks info update")

        if case let .success(optionalChange) = result, optionalChange != nil {
            logger.debug("Did change balance locks")

            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletBalanceChanged())
            }
        }
    }
}
