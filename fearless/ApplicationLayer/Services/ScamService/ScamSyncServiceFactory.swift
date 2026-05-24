import Foundation
import RobinHood
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

protocol ScamListConfigSource {
    var scamListCsvURL: URL? { get }
}

extension ApplicationConfig: ScamListConfigSource {}

struct ScamSyncServiceFactoryDependencies {
    let configSource: ScamListConfigSource
    let storageFacade: StorageFacadeProtocol
    let dataFetchFactory: DataOperationFactoryProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue

    init(
        configSource: ScamListConfigSource = ApplicationConfig.shared,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        dataFetchFactory: DataOperationFactoryProtocol = DataOperationFactory(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    ) {
        self.configSource = configSource
        self.storageFacade = storageFacade
        self.dataFetchFactory = dataFetchFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
    }
}

enum ScamSyncServiceFactory {
    static func createService(
        dependencies: ScamSyncServiceFactoryDependencies = ScamSyncServiceFactoryDependencies()
    ) -> ScamSyncServiceProtocol {
        let mapper: CodableCoreDataMapper<ScamInfo, SSFAssetManagmentStorage.CDScamInfo> =
            // Use a literal to avoid module-qualified #keyPath limitation
            CodableCoreDataMapper(entityIdentifierFieldName: "address")

        let repository: CoreDataRepository<ScamInfo, SSFAssetManagmentStorage.CDScamInfo> =
            dependencies.storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = ScamSyncService(
            scamListCsvURL: dependencies.configSource.scamListCsvURL,
            repository: AnyDataProviderRepository(repository),
            dataFetchFactory: dependencies.dataFetchFactory,
            retryStrategy: dependencies.retryStrategy,
            operationQueue: dependencies.operationQueue
        )

        return service
    }
}
