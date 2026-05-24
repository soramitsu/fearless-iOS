import Foundation
import RobinHood
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

protocol PhishingListConfigSource {
    var phishingListURL: URL { get }
}

extension ApplicationConfig: PhishingListConfigSource {}

struct GitHubPhishingServiceFactoryDependencies {
    let configSource: PhishingListConfigSource
    let storageFacade: StorageFacadeProtocol
    let operationFactory: GitHubOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        configSource: PhishingListConfigSource = ApplicationConfig.shared,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        operationFactory: GitHubOperationFactoryProtocol = GitHubOperationFactory(),
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager
    ) {
        self.configSource = configSource
        self.storageFacade = storageFacade
        self.operationFactory = operationFactory
        self.operationManager = operationManager
    }
}

enum GitHubPhishingServiceFactory {
    static func createService(
        dependencies: GitHubPhishingServiceFactoryDependencies = GitHubPhishingServiceFactoryDependencies()
    ) -> ApplicationServiceProtocol {
        let storage: CoreDataRepository<PhishingItem, SSFAssetManagmentStorage.CDPhishingItem> =
            dependencies.storageFacade.createRepository()
        let url = dependencies.configSource.phishingListURL

        let gitHubPhishingService: ApplicationServiceProtocol =
            GitHubPhishingAPIService(
                url: url,
                operationFactory: dependencies.operationFactory,
                operationManager: dependencies.operationManager,
                storage: storage
            )

        return gitHubPhishingService
    }
}
