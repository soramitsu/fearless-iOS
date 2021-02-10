import Foundation
import RobinHood

protocol GitHubPhishingServiceFactoryProtocol {
    func createGitHubService() -> ApplicationServiceProtocol
}

class GitHubPhishingServiceFactory: GitHubPhishingServiceFactoryProtocol {

    lazy var endPoint: String = { return "https://polkadot.js.org/phishing/address.json" }()

    func createGitHubService() -> ApplicationServiceProtocol {
        let logger = Logger.shared
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let url = URL(string: endPoint)!

        let networkOperation = GitHubOperationFactory().fetchPhishingListOperation(url)

        let gitHubPhishingService: ApplicationServiceProtocol =
            GitHubPhishingAPIService(operation: networkOperation,
                                     logger: logger,
                                     storage: storage)

        return gitHubPhishingService
    }
}
