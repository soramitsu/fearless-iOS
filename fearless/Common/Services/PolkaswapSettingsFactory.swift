import Foundation
import RobinHood
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

protocol PolkaswapSettingsConfigSource {
    var polkaswapSettingsURL: URL? { get }
}

extension ApplicationConfig: PolkaswapSettingsConfigSource {}

struct PolkaswapSettingsFactoryDependencies {
    let configSource: PolkaswapSettingsConfigSource
    let storageFacade: StorageFacadeProtocol
    let dataFetchFactory: DataOperationFactoryProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue

    init(
        configSource: PolkaswapSettingsConfigSource = ApplicationConfig.shared,
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

enum PolkaswapSettingsFactory {
    static func createService(
        dependencies: PolkaswapSettingsFactoryDependencies = PolkaswapSettingsFactoryDependencies()
    ) -> PolkaswapSettingsSyncServiceProtocol {
        let mapper = PolkaswapSettingMapper()

        let repository: CoreDataRepository<PolkaswapRemoteSettings, SSFAssetManagmentStorage.CDPolkaswapRemoteSettings>
            = dependencies.storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = PolkaswapSettingsSyncService(
            settingsUrl: dependencies.configSource.polkaswapSettingsURL,
            dataFetchFactory: dependencies.dataFetchFactory,
            repository: AnyDataProviderRepository(repository),
            operationQueue: dependencies.operationQueue,
            retryStrategy: dependencies.retryStrategy
        )

        return service
    }
}
