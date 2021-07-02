import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    let storageKeyFactory = StorageKeyFactory()
    let addressFactory = SS58AddressFactory()
    let operationManager: OperationManagerProtocol
    let eventCenter = EventCenter.shared
    let logger = Logger.shared

    let runtimeService: RuntimeCodingServiceProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.storageFacade = storageFacade
        self.runtimeService = runtimeService
        self.operationManager = operationManager

        providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )
    }

    func createSubscriptions(
        address: String,
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing] {
        let accountId = try addressFactory.accountId(fromAddress: address, type: type)

        let localStorageIdFactory = try ChainStorageIdFactory(chain: type.chain)

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: operationManager,
            eventCenter: eventCenter,
            localKeyFactory: localStorageIdFactory,
            logger: logger
        )

        let transactionSubscription = createTransactionSubscription(
            address: address,
            engine: engine,
            networkType: type
        )

        let accountSubscription =
            try createAccountInfoSubscription(
                transactionSubscription: transactionSubscription,
                accountId: accountId,
                localStorageIdFactory: localStorageIdFactory
            )

        let accountSubscriptions: [StorageChildSubscribing] = [
            accountSubscription
        ]

        let globalSubscriptions = try createGlobalSubscriptions(childSubscriptionFactory)

        let globalSubscriptionContainer = StorageSubscriptionContainer(
            engine: engine,
            children: globalSubscriptions,
            logger: Logger.shared
        )

        let accountSubscriptionContainer = StorageSubscriptionContainer(
            engine: engine,
            children: accountSubscriptions,
            logger: Logger.shared
        )

        let runtimeSubscription = createRuntimeVersionSubscription(
            engine: engine,
            networkType: type
        )

        let commonStakingSubscription = try createCommonStakingSubscription(
            childSubscriptionFactory,
            engine: engine
        )

        let stakingResolver = createStakingResolver(
            address: address,
            childSubscriptionFactory: childSubscriptionFactory,
            engine: engine,
            networkType: type
        )

        let stakingSubscription =
            createStakingSubscription(
                address: address,
                engine: engine,
                childSubscriptionFactory: childSubscriptionFactory,
                networkType: type
            )

        return [
            globalSubscriptionContainer,
            accountSubscriptionContainer,
            runtimeSubscription,
            commonStakingSubscription,
            stakingResolver,
            stakingSubscription
        ]
    }

    private func createGlobalSubscriptions(_ factory: ChildSubscriptionFactoryProtocol)
        throws -> [StorageChildSubscribing] {
        let activeEraSubscription = try createActiveEraSubscription(factory)

        let currentEraSubscription = try createCurrentEraSubscription(factory)

        let totalIssuanceSubscription = try createTotalIssuanceSubscription(factory)

        let historyDepthSubscription = try createHistoryDepthSubscription(factory)

        let blockNumberSubscription = try createBlockNumberSubscription(factory)

        let subscriptions: [StorageChildSubscribing] = [
            activeEraSubscription,
            currentEraSubscription,
            totalIssuanceSubscription,
            historyDepthSubscription,
            blockNumberSubscription
        ]

        return subscriptions
    }

    private func createAccountInfoSubscription(
        transactionSubscription: TransactionSubscription,
        accountId: Data,
        localStorageIdFactory: ChainStorageIdFactoryProtocol
    )
        throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.accountInfoKeyForId(accountId)

        let localStorageKey = localStorageIdFactory.createIdentifier(for: accountStorageKey)

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AccountInfoSubscription(
            transactionSubscription: transactionSubscription,
            remoteStorageKey: accountStorageKey,
            localStorageKey: localStorageKey,
            storage: AnyDataProviderRepository(storage),
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared,
            eventCenter: EventCenter.shared
        )
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

    private func createCommonStakingSubscription(
        _ factory: ChildSubscriptionFactoryProtocol,
        engine: JSONRPCEngine
    )
        throws -> WebSocketSubscribing {
        let subscription = CommonStakingSubscription(
            engine: engine,
            runtimeService: runtimeService,
            childSubscriptionFactory: factory,
            operationManager: operationManager,
            logger: logger
        )

        return subscription
    }

    private func createTransactionSubscription(
        address: String,
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> TransactionSubscription {
        let filter = NSPredicate.filterTransactionsBy(address: address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            storageFacade.createRepository(filter: filter)

        let contactOperationFactory = WalletContactOperationFactory(
            storageFacade: storageFacade,
            targetAddress: address
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: storageKeyFactory,
            operationManager: operationManager
        )

        return TransactionSubscription(
            engine: engine,
            address: address,
            chain: networkType.chain,
            runtimeService: runtimeService,
            txStorage: AnyDataProviderRepository(txStorage),
            contactOperationFactory: contactOperationFactory,
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }

    private func createRuntimeVersionSubscription(
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> RuntimeVersionSubscription {
        let chain = networkType.chain

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: chain.genesisHash)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository(filter: filter)

        return RuntimeVersionSubscription(
            chain: chain,
            storage: AnyDataProviderRepository(storage),
            engine: engine,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createStakingResolver(
        address: String,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        engine: JSONRPCEngine,
        networkType: SNAddressType
    ) -> StakingAccountResolver {
        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))

        let filter = NSPredicate.filterByStashOrController(address)
        let repository: CoreDataRepository<StashItem, CDStashItem> = storageFacade
            .createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        return StakingAccountResolver(
            address: address,
            chain: networkType.chain,
            engine: engine,
            runtimeService: runtimeService,
            repository: AnyDataProviderRepository(repository),
            childSubscriptionFactory: childSubscriptionFactory,
            addressFactory: addressFactory,
            operationManager: operationManager,
            logger: logger
        )
    }

    private func createStakingSubscription(
        address: String,
        engine: JSONRPCEngine,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        networkType: SNAddressType
    ) -> StakingAccountSubscription {
        let provider = providerFactory.createStashItemProvider(for: address)

        return StakingAccountSubscription(
            address: address,
            chain: networkType.chain,
            engine: engine,
            provider: provider,
            runtimeService: runtimeService,
            childSubscriptionFactory: childSubscriptionFactory,
            operationManager: operationManager,
            addressFactory: addressFactory,
            logger: logger
        )
    }

    private func createHistoryDepthSubscription(
        _ factory: ChildSubscriptionFactoryProtocol
    ) throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.historyDepth()
        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }

    private func createBlockNumberSubscription(
        _ factory: ChildSubscriptionFactoryProtocol
    ) throws -> StorageChildSubscribing {
        let remoteStorageKey = try storageKeyFactory.key(from: .blockNumber)
        return factory.createEmptyHandlingSubscription(remoteKey: remoteStorageKey)
    }
}
