import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    private var networkOperation: BaseOperation<[PhishingItem]>!
    private let operationFactory: GitHubOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let url: URL
    private let storage: CoreDataRepository<PhishingItem, CDPhishingItem>

    init(
        url: URL,
        operationFactory: GitHubOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        storage: CoreDataRepository<PhishingItem, CDPhishingItem>
    ) {
        self.url = url
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.storage = storage
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

        let operationWrapper = CompoundOperationWrapper(
            targetOperation: replaceOperation,
            dependencies: [networkOperation]
        )

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}
