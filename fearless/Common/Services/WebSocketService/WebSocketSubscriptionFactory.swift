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
        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)

        let transferSubscription = createTransferSubscription(address: address,
                                                              engine: engine,
                                                              networkType: type,
                                                              addressFactory: addressFactory)

        let accountSubscription = try createAccountInfoSubscription(transferSubscription: transferSubscription,
                                                                    accountId: accountId,
                                                                    storageKeyFactory: keyFactory,
                                                                    localStorageIdFactory:
                                                                        localStorageIdFactory)

        let activeEraSubscription = try createActiveEraSubscription(storageKeyFactory: keyFactory,
                                                                    localStorageIdFactory:
                                                                        localStorageIdFactory)

        let stakingSubscription = try createStakingSubscription(engine: engine,
                                                                accountId: accountId,
                                                                localStorageIdFactory:
                                                                    localStorageIdFactory)

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
                                               storageKeyFactory: StorageKeyFactoryProtocol,
                                               localStorageIdFactory: ChainStorageIdFactoryProtocol)
        throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let localStorageKey = try localStorageIdFactory.createIdentifier(for: accountStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return AccountInfoSubscription(transferSubscription: transferSubscription,
                                       remoteStorageKey: accountStorageKey,
                                       localStorageKey: localStorageKey,
                                       storage: AnyDataProviderRepository(storage),
                                       operationManager: OperationManagerFacade.sharedManager,
                                       logger: Logger.shared,
                                       eventCenter: EventCenter.shared)
    }

    private func createActiveEraSubscription(storageKeyFactory: StorageKeyFactoryProtocol,
                                             localStorageIdFactory: ChainStorageIdFactoryProtocol)
        throws -> ActiveEraSubscription {
        let remoteStorageKey = try storageKeyFactory.activeEra()
        let localStorageKey = try localStorageIdFactory.createIdentifier(for: remoteStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return ActiveEraSubscription(remoteStorageKey: remoteStorageKey,
                                     localStorageKey: localStorageKey,
                                     storage: AnyDataProviderRepository(storage),
                                     operationManager: OperationManagerFacade.sharedManager,
                                     logger: Logger.shared,
                                     eventCenter: EventCenter.shared)
    }

    private func createStakingSubscription(engine: JSONRPCEngine,
                                           accountId: Data,
                                           localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> StakingInfoSubscription {

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        return StakingInfoSubscription(engine: engine,
                                       stashId: accountId,
                                       storage: AnyDataProviderRepository(storage),
                                       localStorageIdFactory: localStorageIdFactory,
                                       operationManager: OperationManagerFacade.sharedManager,
                                       eventCenter: EventCenter.shared,
                                       logger: Logger.shared)
    }

    private func createBondedSubscription(accountId: Data,
                                          stakingSubscription: StakingInfoSubscription,
                                          storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> BondedSubscription {
        let storageKey = try storageKeyFactory.bondedKeyForId(accountId)

        return BondedSubscription(remoteStorageKey: storageKey,
                                  stakingSubscription: stakingSubscription,
                                  logger: Logger.shared)
    }

    private func createTransferSubscription(address: String,
                                            engine: JSONRPCEngine,
                                            networkType: SNAddressType,
                                            addressFactory: SS58AddressFactoryProtocol)
        -> TransferSubscription {
        let storageFacade = SubstrateDataStorageFacade.shared

        let filter = NSPredicate.filterTransactionsBy(address: address)
        let storage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
                storageFacade.createRepository(filter: filter)

        let contactOperationFactory = WalletContactOperationFactory(storageFacade: storageFacade,
                                                                    targetAddress: address)

        return TransferSubscription(engine: engine,
                                    address: address,
                                    chain: networkType.chain,
                                    addressFactory: addressFactory,
                                    storage: AnyDataProviderRepository(storage),
                                    contactOperationFactory: contactOperationFactory,
                                    operationManager: OperationManagerFacade.sharedManager,
                                    eventCenter: EventCenter.shared,
                                    logger: Logger.shared)
    }
}
