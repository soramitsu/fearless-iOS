import Foundation
import RobinHood

final class ChainRegistryFactory {
    static func createDefaultRegistry() -> ChainRegistryProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared

        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            repositoryFacade.createRepository()

        let dataFetchOperationFactory = DataOperationFactory()

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesOperationFactory = RuntimeFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: runtimeDirectory
        )

        let runtimeSyncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared
        )

        let runtimeProviderFactory = RuntimeProviderFactory(
            fileOperationFactory: filesOperationFactory,
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue
        )

        let runtimeProviderPool = RuntimeProviderPool(
            cacheLimit: 4,
            runtimeProviderFactory: runtimeProviderFactory
        )

        let connectionPool = ConnectionPool(
            connectionFactory: ConnectionFactory(logger: Logger.shared)
        )

        let mapper = ChainModelMapper()
        let chainRepository: CoreDataRepository<ChainModel, CDChain> =
            repositoryFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let chainObserver = CoreDataContextObservable(
            service: repositoryFacade.databaseService,
            mapper: chainRepository.dataMapper,
            predicate: { _ in true }
        )

        let chainProvider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(chainRepository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )

        let chainSyncService = ChainSyncService(
            url: ApplicationConfig.shared.chainListURL,
            dataFetchFactory: dataFetchOperationFactory,
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedQueue
        )

        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactory(
            runtimeSyncService: runtimeSyncService,
            logger: Logger.shared
        )

        return ChainRegistry(
            runtimeProviderPool: runtimeProviderPool,
            connectionPool: connectionPool,
            chainSyncService: chainSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory
        )
    }
}
