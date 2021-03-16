import Foundation
import RobinHood

protocol ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(remoteKey: Data,
                                         eventFactory: @escaping EventEmittingFactoryClosure)
    -> StorageChildSubscribing

    func createEmptyHandlingSubscription(remoteKey: Data) -> StorageChildSubscribing
}

final class ChildSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol
    let operationManager: OperationManagerProtocol
    let localKeyFactory: ChainStorageIdFactoryProtocol
    let eventCenter: EventCenterProtocol

    private lazy var repository: AnyDataProviderRepository<ChainStorageItem> = {
        let coreDataRepository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(coreDataRepository)
    }()

    init(storageFacade: StorageFacadeProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         localKeyFactory: ChainStorageIdFactoryProtocol,
         logger: LoggerProtocol) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.localKeyFactory = localKeyFactory
        self.logger = logger
    }
}

extension ChildSubscriptionFactory: ChildSubscriptionFactoryProtocol {
    func createEventEmittingSubscription(remoteKey: Data,
                                         eventFactory: @escaping EventEmittingFactoryClosure)
    -> StorageChildSubscribing {

        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        return EventEmittingStorageSubscription(remoteStorageKey: remoteKey,
                                                localStorageKey: localKey,
                                                storage: repository,
                                                operationManager: operationManager,
                                                logger: logger,
                                                eventCenter: eventCenter,
                                                eventFactory: eventFactory)
    }

    func createEmptyHandlingSubscription(remoteKey: Data) -> StorageChildSubscribing {
        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        return EmptyHandlingStorageSubscription(remoteStorageKey: remoteKey,
                                                localStorageKey: localKey,
                                                storage: repository,
                                                operationManager: operationManager,
                                                logger: logger)
    }
}
