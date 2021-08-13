import Foundation
import RobinHood

final class ChainRegistryFactory {
    static func createDefaultRegistry() -> ChainRegistryProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared

        let runtimVersionRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            repositoryFacade.createRepository()
        let runtimeSyncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(runtimVersionRepository)
        )

        let runtimeProviderFactory = RuntimeProviderFactory(runtimeSyncService: runtimeSyncService)
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
            dataFetchFactory: DataOperationFactory(),
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedQueue
        )

        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactory(
            runtimeSyncService: runtimeSyncService
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
