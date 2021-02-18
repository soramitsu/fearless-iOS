import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    private var networkOperation: BaseOperation<[PhishingItem]>! = nil
    private var operationFactory: GitHubOperationFactoryProtocol
    private var url: URL
    private var storage: CoreDataRepository<PhishingItem, CDPhishingItem>
    private var logger: LoggerProtocol

    init(url: URL,
         operationFactory: GitHubOperationFactoryProtocol,
         storage: CoreDataRepository<PhishingItem, CDPhishingItem>,
         logger: LoggerProtocol) {
        self.url = url
        self.operationFactory = operationFactory
        self.storage = storage
        self.logger = logger
    }

    enum State {
        case throttled
        case active
        case inactive
    }

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    private func clearConnection() {
        networkOperation.cancel()
    }

    private func setupConnection() {

        networkOperation = GitHubOperationFactory().fetchPhishingListOperation(url)

        let replaceOperation = storage.replaceOperation {
            let phishingItem = try self.networkOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return phishingItem
        }

        replaceOperation.addDependency(networkOperation)

        let operationWrapper = CompoundOperationWrapper(targetOperation: replaceOperation,
                                        dependencies: [networkOperation])

        OperationManagerFacade.sharedManager.enqueue(operations: operationWrapper.allOperations, in: .sync)
    }
}
