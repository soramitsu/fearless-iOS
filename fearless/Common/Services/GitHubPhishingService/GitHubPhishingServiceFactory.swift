import Foundation
import RobinHood

class GitHubPhishingServiceFactory {
    static func createService() -> ApplicationServiceProtocol {
        let logger = Logger.shared
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let url = config.phishingListURL

        let networkOoperationFactory = GitHubOperationFactory()
        let operationManager = OperationManagerFacade.sharedManager

        let gitHubPhishingService: ApplicationServiceProtocol =
            GitHubPhishingAPIService(url: url,
                                     operationFactory: networkOoperationFactory,
                                     operationManager: operationManager,
                                     storage: storage,
                                     logger: logger)

        return gitHubPhishingService
    }
}
