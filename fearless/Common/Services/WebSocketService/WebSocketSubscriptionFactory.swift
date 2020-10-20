import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing] {
        let accountId = try SS58AddressFactory().accountId(fromAddress: address,
                                                           type: type)

        let keyFactory = StorageKeyFactory()

        let accountSubscription = try createAccountInfoSubscription(accountId: accountId,
                                                                    storageKeyFactory: keyFactory)

        let activeEraSubscription = try createActiveEraSubscription(storageKeyFactory: keyFactory)

        let stakingSubscription = try createStakingSubscription(engine: engine,
                                                                accountId: accountId)

        let bondedSubscription = try createBondedSubscription(accountId: accountId,
                                                              stakingSubscription: stakingSubscription,
                                                              storageKeyFactory: keyFactory)

        let children: [StorageChildSubscribing] = [
            accountSubscription,
            bondedSubscription,
            activeEraSubscription
        ]

        let container = StorageSubscriptionContainer(engine: engine,
                                                     children: children,
                                                     logger: Logger.shared)

        return [container, stakingSubscription]
    }

    private func createAccountInfoSubscription(accountId: Data,
                                               storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return AccountInfoSubscription(storageKey: accountStorageKey,
                                       storage: AnyDataProviderRepository(storage),
                                       operationManager: OperationManagerFacade.sharedManager,
                                       logger: Logger.shared,
                                       eventCenter: EventCenter.shared)
    }

    private func createActiveEraSubscription(storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> ActiveEraSubscription {
        let storageKey = try storageKeyFactory.activeEra()

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return ActiveEraSubscription(storageKey: storageKey,
                                     storage: AnyDataProviderRepository(storage),
                                     operationManager: OperationManagerFacade.sharedManager,
                                     logger: Logger.shared,
                                     eventCenter: EventCenter.shared)
    }

    private func createStakingSubscription(engine: JSONRPCEngine,
                                           accountId: Data) throws -> StakingInfoSubscription {

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return StakingInfoSubscription(engine: engine,
                                       stashId: accountId,
                                       storage: AnyDataProviderRepository(storage),
                                       operationManager: OperationManagerFacade.sharedManager,
                                       eventCenter: EventCenter.shared,
                                       logger: Logger.shared)
    }

    private func createBondedSubscription(accountId: Data,
                                          stakingSubscription: StakingInfoSubscription,
                                          storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> BondedSubscription {
        let storageKey = try storageKeyFactory.bondedKeyForId(accountId)

        return BondedSubscription(storageKey: storageKey,
                                  stakingSubscription: stakingSubscription,
                                  logger: Logger.shared)
    }
}
