import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing] {
        let addressFactory = SS58AddressFactory()
        let accountId = try addressFactory.accountId(fromAddress: address, type: type)

        let keyFactory = StorageKeyFactory()
        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)
        let operationManager = OperationManagerFacade.sharedManager
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let runtimeService = RuntimeRegistryFacade.sharedService
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager)

        let childSubscriptionFactory = ChildSubscriptionFactory(storageFacade: storageFacade,
                                                                operationManager: operationManager,
                                                                eventCenter: eventCenter,
                                                                localKeyFactory: localStorageIdFactory,
                                                                logger: logger)

        let transferSubscription = createTransferSubscription(address: address,
                                                              engine: engine,
                                                              networkType: type,
                                                              addressFactory: addressFactory,
                                                              localStorageIdFactory: localStorageIdFactory)

        let accountSubscription = try createAccountInfoSubscription(transferSubscription: transferSubscription,
                                                                    accountId: accountId,
                                                                    storageKeyFactory: keyFactory,
                                                                    localStorageIdFactory:
                                                                        localStorageIdFactory)

        let accountSubscriptions: [StorageChildSubscribing] = [
            accountSubscription
        ]

        let globalSubscriptions: [StorageChildSubscribing] = try createGlobalSubscriptions(
            keyFactory: keyFactory,
            localStorageIdFactory: localStorageIdFactory)

        let globalSubscriptionContainer = StorageSubscriptionContainer(engine: engine,
                                                                       children: globalSubscriptions,
                                                                       logger: Logger.shared)

        let accountSubscriptionContainer = StorageSubscriptionContainer(engine: engine,
                                                                        children: accountSubscriptions,
                                                                        logger: Logger.shared)

        let runtimeSubscription = createRuntimeVersionSubscription(engine: engine,
                                                                   networkType: type)

        let stakingResolver = createStakingResolver(address: address,
                                                    childSubscriptionFactory: childSubscriptionFactory,
                                                    runtimeService: runtimeService,
                                                    engine: engine,
                                                    networkType: type,
                                                    addressFactory: addressFactory)

        let stakingSubscription = createStakingSubscription(address: address,
                                                            engine: engine,
                                                            dataProviderFactory: providerFactory,
                                                            childSubscriptionFactory: childSubscriptionFactory,
                                                            runtimeService: runtimeService,
                                                            networkType: type,
                                                            addressFactory: addressFactory)

        return [globalSubscriptionContainer,
                accountSubscriptionContainer,
                runtimeSubscription,
                stakingResolver,
                stakingSubscription]
    }

    private func createGlobalSubscriptions(keyFactory: StorageKeyFactoryProtocol,
                                           localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> [StorageChildSubscribing] {
        let upgradeV28Subscription = try createV28Subscription(
            storageKeyFactory: keyFactory,
            localStorageIdFactory: localStorageIdFactory)

        let activeEraSubscription = try createActiveEraSubscription(
            storageKeyFactory: keyFactory,
            localStorageIdFactory: localStorageIdFactory)

        let currentEraSubscription = try createCurrentEraSubscription(
            storageKeyFactory: keyFactory,
            localStorageIdFactory: localStorageIdFactory)

        let totalIssuanceSubscription = try createTotalIssuanceSubscription(
            storageKeyFactory: keyFactory,
            localStorageIdFactory: localStorageIdFactory)

        let subscriptions: [StorageChildSubscribing] = [
            upgradeV28Subscription,
            activeEraSubscription,
            currentEraSubscription,
            totalIssuanceSubscription
        ]

        return subscriptions
    }

    private func createAccountInfoSubscription(transferSubscription: TransferSubscription,
                                               accountId: Data,
                                               storageKeyFactory: StorageKeyFactoryProtocol,
                                               localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let localStorageKey = localStorageIdFactory.createIdentifier(for: accountStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

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
        let localStorageKey = localStorageIdFactory.createIdentifier(for: remoteStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return ActiveEraSubscription(remoteStorageKey: remoteStorageKey,
                                     localStorageKey: localStorageKey,
                                     storage: AnyDataProviderRepository(storage),
                                     operationManager: OperationManagerFacade.sharedManager,
                                     logger: Logger.shared,
                                     eventCenter: EventCenter.shared)
    }

    private func createCurrentEraSubscription(storageKeyFactory: StorageKeyFactoryProtocol,
                                              localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> CurrentEraSubscription {
        let remoteStorageKey = try storageKeyFactory.currentEra()
        let localStorageKey = localStorageIdFactory.createIdentifier(for: remoteStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return CurrentEraSubscription(remoteStorageKey: remoteStorageKey,
                                      localStorageKey: localStorageKey,
                                      storage: AnyDataProviderRepository(storage),
                                      operationManager: OperationManagerFacade.sharedManager,
                                      logger: Logger.shared,
                                      eventCenter: EventCenter.shared)
    }

    private func createTotalIssuanceSubscription(storageKeyFactory: StorageKeyFactoryProtocol,
                                                 localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> TotalIssuanceSubscription {
        let remoteStorageKey = try storageKeyFactory.totalIssuance()
        let localStorageKey = localStorageIdFactory.createIdentifier(for: remoteStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return TotalIssuanceSubscription(remoteStorageKey: remoteStorageKey,
                                         localStorageKey: localStorageKey,
                                         storage: AnyDataProviderRepository(storage),
                                         operationManager: OperationManagerFacade.sharedManager,
                                         logger: Logger.shared,
                                         eventCenter: EventCenter.shared)
    }

    private func createV28Subscription(storageKeyFactory: StorageKeyFactoryProtocol,
                                       localStorageIdFactory: ChainStorageIdFactoryProtocol)
    throws -> UpgradeV28Subscription {
        let remoteStorageKey = try storageKeyFactory.updatedDualRefCount()
        let localStorageKey = localStorageIdFactory.createIdentifier(for: remoteStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return UpgradeV28Subscription(remoteStorageKey: remoteStorageKey,
                                      localStorageKey: localStorageKey,
                                      storage: AnyDataProviderRepository(storage),
                                      operationManager: OperationManagerFacade.sharedManager,
                                      logger: Logger.shared,
                                      eventCenter: EventCenter.shared)
    }

    private func createTransferSubscription(address: String,
                                            engine: JSONRPCEngine,
                                            networkType: SNAddressType,
                                            addressFactory: SS58AddressFactoryProtocol,
                                            localStorageIdFactory: ChainStorageIdFactoryProtocol)
    -> TransferSubscription {
        let filter = NSPredicate.filterTransactionsBy(address: address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            storageFacade.createRepository(filter: filter)

        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        let contactOperationFactory = WalletContactOperationFactory(storageFacade: storageFacade,
                                                                    targetAddress: address)

        return TransferSubscription(engine: engine,
                                    address: address,
                                    chain: networkType.chain,
                                    addressFactory: addressFactory,
                                    txStorage: AnyDataProviderRepository(txStorage),
                                    chainStorage: AnyDataProviderRepository(chainStorage),
                                    localIdFactory: localStorageIdFactory,
                                    contactOperationFactory: contactOperationFactory,
                                    operationManager: OperationManagerFacade.sharedManager,
                                    eventCenter: EventCenter.shared,
                                    logger: Logger.shared)
    }

    private func createRuntimeVersionSubscription(engine: JSONRPCEngine,
                                                  networkType: SNAddressType)
    -> RuntimeVersionSubscription {
        let chain = networkType.chain

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: chain.genesisHash)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository(filter: filter)

        return RuntimeVersionSubscription(chain: chain,
                                          storage: AnyDataProviderRepository(storage),
                                          engine: engine,
                                          operationManager: OperationManagerFacade.sharedManager,
                                          logger: Logger.shared)
    }

    private func createStakingResolver(address: String,
                                       childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
                                       runtimeService: RuntimeCodingServiceProtocol,
                                       engine: JSONRPCEngine,
                                       networkType: SNAddressType,
                                       addressFactory: SS58AddressFactoryProtocol) -> StakingAccountResolver {

        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))

        let filter = NSPredicate.filterByStashOrController(address)
        let repository: CoreDataRepository<StashItem, CDStashItem> = storageFacade
            .createRepository(filter: filter,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(mapper))

        return StakingAccountResolver(address: address,
                                      chain: networkType.chain,
                                      engine: engine,
                                      runtimeService: runtimeService,
                                      repository: AnyDataProviderRepository(repository),
                                      childSubscriptionFactory: childSubscriptionFactory,
                                      addressFactory: addressFactory,
                                      operationManager: OperationManagerFacade.sharedManager,
                                      logger: Logger.shared)
    }

    private func createStakingSubscription(address: String,
                                           engine: JSONRPCEngine,
                                           dataProviderFactory: SubstrateDataProviderFactoryProtocol,
                                           childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
                                           runtimeService: RuntimeCodingServiceProtocol,
                                           networkType: SNAddressType,
                                           addressFactory: SS58AddressFactoryProtocol)
    -> StakingAccountSubscription {

        let provider = dataProviderFactory.createStashItemProvider(for: address)

        return StakingAccountSubscription(address: address,
                                          chain: networkType.chain,
                                          engine: engine,
                                          provider: provider,
                                          runtimeService: runtimeService,
                                          childSubscriptionFactory: childSubscriptionFactory,
                                          operationManager: OperationManagerFacade.sharedManager,
                                          addressFactory: addressFactory,
                                          logger: Logger.shared)
    }
}
