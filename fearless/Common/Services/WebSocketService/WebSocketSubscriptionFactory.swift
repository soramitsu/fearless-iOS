import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    let storageKeyFactory = StorageKeyFactory()
    let addressFactory = SS58AddressFactory()
    let operationManager = OperationManagerFacade.sharedManager
    let eventCenter = EventCenter.shared
    let logger = Logger.shared

    let runtimeService = RuntimeRegistryFacade.sharedService
    let providerFactory: SubstrateDataProviderFactoryProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade

        providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                       operationManager: operationManager)
    }

    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing] {

        let accountId = try addressFactory.accountId(fromAddress: address, type: type)

        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)

        let childSubscriptionFactory = ChildSubscriptionFactory(storageFacade: storageFacade,
                                                                operationManager: operationManager,
                                                                eventCenter: eventCenter,
                                                                localKeyFactory: localStorageIdFactory,
                                                                logger: logger)

        let transferSubscription = createTransferSubscription(address: address,
                                                              engine: engine,
                                                              networkType: type,
                                                              localStorageIdFactory: localStorageIdFactory)

        let accountSubscription =
            try createAccountInfoSubscription(transferSubscription: transferSubscription,
                                              accountId: accountId,
                                              localStorageIdFactory: localStorageIdFactory)

        let accountSubscriptions: [StorageChildSubscribing] = [
            accountSubscription
        ]

        let globalSubscriptions = try createGlobalSubscriptions(childSubscriptionFactory)

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
                                                    engine: engine,
                                                    networkType: type)

        let stakingSubscription =
            createStakingSubscription(address: address,
                                      engine: engine,
                                      childSubscriptionFactory: childSubscriptionFactory,
                                      networkType: type)

        return [globalSubscriptionContainer,
                accountSubscriptionContainer,
                runtimeSubscription,
                stakingResolver,
                stakingSubscription]
    }

    private func createGlobalSubscriptions(_ factory: ChildSubscriptionFactoryProtocol)
    throws -> [StorageChildSubscribing] {
        let upgradeV28Subscription = try createV28Subscription(factory)

        let activeEraSubscription = try createActiveEraSubscription(factory)

        let currentEraSubscription = try createCurrentEraSubscription(factory)

        let totalIssuanceSubscription = try createTotalIssuanceSubscription(factory)

        let electionStatusSubscription = try createElectionStatusSubscription(factory)

        let subscriptions: [StorageChildSubscribing] = [
            electionStatusSubscription,
            upgradeV28Subscription,
            activeEraSubscription,
            currentEraSubscription,
            totalIssuanceSubscription
        ]

        return subscriptions
    }

    private func createAccountInfoSubscription(transferSubscription: TransferSubscription,
                                               accountId: Data,
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

    private func createActiveEraSubscription(_ factory: ChildSubscriptionFactoryProtocol)
    throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.activeEra()

        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createCurrentEraSubscription(_ childFactory: ChildSubscriptionFactoryProtocol)
    throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.currentEra()
        return childFactory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createTotalIssuanceSubscription(_ factory: ChildSubscriptionFactoryProtocol)
    throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.totalIssuance()

        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createElectionStatusSubscription(_ factory: ChildSubscriptionFactoryProtocol)
    throws -> StorageChildSubscribing {
        let path = StorageCodingPath.electionStatus
        let remoteStorageKey = try storageKeyFactory.createStorageKey(moduleName: path.moduleName,
                                                                      storageName: path.itemName)
        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createV28Subscription(_ factory: ChildSubscriptionFactoryProtocol)
    throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.updatedDualRefCount()

        return factory.createEventEmittingSubscription(remoteKey: remoteStorageKey) { _ in
            WalletBalanceChanged()
        }
    }

    private func createTransferSubscription(address: String,
                                            engine: JSONRPCEngine,
                                            networkType: SNAddressType,
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
                                          operationManager: operationManager,
                                          logger: logger)
    }

    private func createStakingResolver(address: String,
                                       childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
                                       engine: JSONRPCEngine,
                                       networkType: SNAddressType) -> StakingAccountResolver {

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
                                      operationManager: operationManager,
                                      logger: logger)
    }

    private func createStakingSubscription(address: String,
                                           engine: JSONRPCEngine,
                                           childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
                                           networkType: SNAddressType)
    -> StakingAccountSubscription {

        let provider = providerFactory.createStashItemProvider(for: address)

        return StakingAccountSubscription(address: address,
                                          chain: networkType.chain,
                                          engine: engine,
                                          provider: provider,
                                          runtimeService: runtimeService,
                                          childSubscriptionFactory: childSubscriptionFactory,
                                          operationManager: operationManager,
                                          addressFactory: addressFactory,
                                          logger: logger)
    }
}
