import Foundation
import RobinHood

typealias EventEmittingFactoryClosure = (DataProviderChange<ChainStorageItem>) -> EventProtocol

final class EventEmittingStorageSubscription: BaseStorageChildSubscription {
    let eventCenter: EventCenterProtocol

    let eventFactory: EventEmittingFactoryClosure

    init(remoteStorageKey: Data,
         localStorageKey: String,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol,
         eventCenter: EventCenterProtocol,
         eventFactory: @escaping EventEmittingFactoryClosure) {
        self.eventCenter = eventCenter
        self.eventFactory = eventFactory

        super.init(remoteStorageKey: remoteStorageKey,
                   localStorageKey: localStorageKey,
                   storage: storage,
                   operationManager: operationManager,
                   logger: logger)
    }

    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        if case .success(let optionalChange) = result, let change = optionalChange {
            DispatchQueue.main.async {
                let event = self.eventFactory(change)
                self.eventCenter.notify(with: event)
            }
        }
    }
}
