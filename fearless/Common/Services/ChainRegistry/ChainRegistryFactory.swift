import Foundation
import RobinHood
import SSFModels
import SSFNetwork
import SSFChainRegistry

/**
 *  Class is designed to handle creation of `ChainRegistryProtocol` instance for application.
 *
 *  Here is list of important config settings applied:
 *  - common and chain types are saved to `Caches` (if unavailable then `tmp` is used)
 *      in `runtime` directory;
 *  - `OperationManagerFacade.runtimeBuildingQueue` queue is used for chain registry
 *      to perform operations faster with `userInitiated` quality of service.
 */

final class ChainRegistryFactory {
    /**
     *  Creates chain registry with on-disk database manager. This function must be used by the application
     *  by default.
     *
     *  - Returns: new instance conforming to `ChainRegistryProtocol`.
     */

    static func createDefaultRegistry() -> ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        return createDefaultRegistry(from: repositoryFacade)
    }

    // swiftlint:disable function_body_length

    /**
     *  Creates chain registry with provided database manager. This function must be used when
     *  there is a need to override `createDefaultRegistry()` behavior that stores database on disk.
     *  For example, in tests it is more conveinent to use in-memory database.
     *
     *  - Parameters:
     *      - repositoryFacade: Database manager to use for chain registry.
     *
     *  - Returns: new instance conforming to `ChainRegistryProtocol`.
     */
    static func createDefaultRegistry(
        from repositoryFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol {
        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            repositoryFacade.createRepository()

        let dataFetchOperationFactory = DataOperationFactory()

        let filesOperationFactory = createFilesOperationFactory()

        let runtimeSyncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        let runtimeProviderFactory = RuntimeProviderFactory(
            fileOperationFactory: filesOperationFactory,
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let runtimeProviderPool = RuntimeProviderPool(runtimeProviderFactory: runtimeProviderFactory)
        let chainRepositoryFactory = ChainRepositoryFactory(storageFacade: repositoryFacade)
        let chainRepository = chainRepositoryFactory.createRepository()
        let chainProvider = createChainProvider(from: repositoryFacade, chainRepository: chainRepository)

        let syncService = SSFChainRegistry.ChainSyncService(
            chainsUrl: ApplicationConfig.shared.chainsSourceUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory()
        )

        let chainSyncService = ChainSyncService(
            syncService: syncService,
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.syncQueue,
            logger: Logger.shared
        )

        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactory(
            runtimeSyncService: runtimeSyncService,
            logger: Logger.shared
        )

        let chainsTypesSuncService = ChainsTypesSyncService(
            url: ApplicationConfig.shared.chainTypesSourceUrl,
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.syncQueue,
            logger: Logger.shared
        )

        let snapshotHotBootBuilder = SnapshotHotBootBuilder(
            runtimeProviderPool: runtimeProviderPool,
            chainRepository: AnyDataProviderRepository(chainRepository),
            filesOperationFactory: filesOperationFactory,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            dataOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let queue = OperationQueue()
        let substrateConnectionPool = ConnectionPool(
            connectionFactory: ConnectionFactory(logger: Logger.shared),
            operationQueue: queue
        )
        let ethereumConnectionPool = EthereumConnectionPool()
        let walletStreamableProvider = createWalletProvider()

        return ChainRegistry(
            snapshotHotBootBuilder: snapshotHotBootBuilder,
            runtimeProviderPool: runtimeProviderPool,
            connectionPools: [substrateConnectionPool, ethereumConnectionPool],
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            chainsTypesSyncService: chainsTypesSuncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            logger: Logger.shared,
            eventCenter: EventCenter.shared,
            walletStreamableProvider: walletStreamableProvider
        )
    }

    private static func createWalletProvider() -> StreamableProvider<ManagedMetaAccountModel> {
        let userStorageFacade = UserDataStorageFacade.shared
        let provider = userStorageFacade.createStreamableProvider(
            filter: NSPredicate.selectedMetaAccount(),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(ManagedMetaAccountMapper())
        )
        return provider
    }

    private static func createFilesOperationFactory() -> RuntimeFilesOperationFactoryProtocol {
        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        return RuntimeFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: runtimeDirectory
        )
    }

    private static func createChainProvider(
        from repositoryFacade: StorageFacadeProtocol,
        chainRepository: CoreDataRepository<ChainModel, CDChain>
    ) -> StreamableProvider<ChainModel> {
        let chainObserver = CoreDataContextObservable(
            service: repositoryFacade.databaseService,
            mapper: chainRepository.dataMapper,
            predicate: { _ in true }
        )

        chainObserver.start { error in
            if let error = error {
                Logger.shared.error("Chain database observer unexpectedly failed: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(chainRepository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
