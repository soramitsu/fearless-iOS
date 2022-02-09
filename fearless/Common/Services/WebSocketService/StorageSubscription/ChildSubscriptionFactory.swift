import Foundation
import RobinHood

protocol ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(
        keys: SubscriptionStorageKeys,
        eventFactory: @escaping EventEmittingFactoryClosure
    ) -> StorageChildSubscribing

    func createEmptyHandlingSubscription(keys: SubscriptionStorageKeys) -> StorageChildSubscribing
}

final class ChildSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(coreDataRepository)
    }()

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger
    }
}

extension ChildSubscriptionFactory: ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(
        keys: SubscriptionStorageKeys,
        eventFactory: @escaping EventEmittingFactoryClosure
    ) -> StorageChildSubscribing {
        EventEmittingStorageSubscription(
            remoteStorageKey: keys.remote,
            localStorageKey: keys.local,
            storage: repository,
            operationManager: operationManager,
            logger: logger,
            eventCenter: eventCenter,
            eventFactory: eventFactory
        )
    }

    func createEmptyHandlingSubscription(keys: SubscriptionStorageKeys) -> StorageChildSubscribing {
        EmptyHandlingStorageSubscription(
            remoteStorageKey: keys.remote,
            localStorageKey: keys.local,
            storage: repository,
            operationManager: operationManager,
            logger: logger
        )
    }
}
