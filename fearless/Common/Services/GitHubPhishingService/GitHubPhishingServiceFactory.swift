import Foundation
import RobinHood

protocol GitHubPhishingServiceFactoryProtocol {
    func createGitHubService() -> ApplicationServiceProtocol
}

class GitHubPhishingServiceFactory: GitHubPhishingServiceFactoryProtocol {

    func createGitHubService() -> ApplicationServiceProtocol {
        let logger = Logger.shared
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let url = config.phishingListURL

        let networkOperation = GitHubOperationFactory().fetchPhishingListOperation(url)

        let gitHubPhishingService: ApplicationServiceProtocol =
            GitHubPhishingAPIService(operation: networkOperation,
                                     logger: logger,
                                     storage: storage)

        return gitHubPhishingService
    }
}
