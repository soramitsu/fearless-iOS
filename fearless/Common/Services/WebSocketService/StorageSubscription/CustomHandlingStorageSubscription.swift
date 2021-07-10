import Foundation
import RobinHood

final class CustomHandlingStorageSubscription: BaseStorageChildSubscription {
    let handler: (DataProviderChange<ChainStorageItem>) -> Void

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol,
        eventCenter _: EventCenterProtocol,
        handler: @escaping (DataProviderChange<ChainStorageItem>) -> Void
    ) {
        self.handler = handler

        super.init(
            remoteStorageKey: remoteStorageKey,
            localStorageKey: localStorageKey,
            storage: storage,
            operationManager: operationManager,
            logger: logger
        )
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash _: Data?) {
        if case let .success(optionalChange) = result, let change = optionalChange {
            DispatchQueue.main.async {
                self.handler(change)
            }
        }
    }
}
