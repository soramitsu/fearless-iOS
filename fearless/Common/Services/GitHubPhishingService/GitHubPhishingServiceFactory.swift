import Foundation
import RobinHood
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

class GitHubPhishingServiceFactory {
    static func createService() -> ApplicationServiceProtocol {
        let storage: CoreDataRepository<PhishingItem, SSFAssetManagmentStorage.CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let url = config.phishingListURL

        let networkOoperationFactory = GitHubOperationFactory()
        let operationManager = OperationManagerFacade.sharedManager

        let gitHubPhishingService: ApplicationServiceProtocol =
            GitHubPhishingAPIService(
                url: url,
                operationFactory: networkOoperationFactory,
                operationManager: operationManager,
                storage: storage
            )

        return gitHubPhishingService
    }
}
