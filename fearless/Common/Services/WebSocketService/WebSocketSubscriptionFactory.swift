import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing] {
        let addressFactory = SS58AddressFactory()
        let accountId = try addressFactory.accountId(fromAddress: address, type: type)

        let keyFactory = StorageKeyFactory()

        let transferSubscription = createTransferSubscription(address: address,
                                                              engine: engine,
                                                              addressType: type,
                                                              addressFactory: addressFactory)

        let accountSubscription = try createAccountInfoSubscription(transferSubscription: transferSubscription,
                                                                    accountId: accountId,
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

    private func createAccountInfoSubscription(transferSubscription: TransferSubscription,
                                               accountId: Data,
                                               storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return AccountInfoSubscription(transferSubscription: transferSubscription,
                                       storageKey: accountStorageKey,
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

    private func createTransferSubscription(address: String,
                                            engine: JSONRPCEngine,
                                            addressType: SNAddressType,
                                            addressFactory: SS58AddressFactoryProtocol)
        -> TransferSubscription {
        let filter = NSPredicate.filterTransactionsBy(address: address)
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
                SubstrateDataStorageFacade.shared.createRepository(filter: filter)

        return TransferSubscription(engine: engine,
                                    address: address,
                                    addressType: addressType,
                                    addressFactory: addressFactory,
                                    storage: AnyDataProviderRepository(storage),
                                    operationManager: OperationManagerFacade.sharedManager,
                                    eventCenter: EventCenter.shared,
                                    logger: Logger.shared)
    }
}
