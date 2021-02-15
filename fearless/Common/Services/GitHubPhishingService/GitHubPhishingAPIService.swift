import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    private var networkOperation: BaseOperation<[PhishingItem]>?
    private var operationFactory: GitHubOperationFactoryProtocol
    private var operationManager: OperationManagerProtocol
    private var url: URL
    private var storage: CoreDataRepository<PhishingItem, CDPhishingItem>
    private var logger: LoggerProtocol

    init(url: URL,
         operationFactory: GitHubOperationFactoryProtocol,
         operationManager: OperationManagerProtocol,
         storage: CoreDataRepository<PhishingItem, CDPhishingItem>,
         logger: LoggerProtocol) {
        self.url = url
        self.operationFactory = operationFactory
        self.operationManager = operationManager
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
        guard let operation = networkOperation else { return }
        operation.cancel()
    }

    private func setupConnection() {
        networkOperation = GitHubOperationFactory().fetchPhishingListOperation(url)
        guard let operation = networkOperation else { return }

        operation.completionBlock = { [self] in
            do {
                if let phishingItems = try operation.extractResultData() {
                    let deleteOperation = storage.deleteAllOperation()
                    operationManager.enqueue(operations: [deleteOperation], in: .sync)

                    for phishingItem in phishingItems {
                        let saveOperation = storage.saveOperation({ [phishingItem] }, { [] })
                        operationManager.enqueue(operations: [saveOperation], in: .sync)
                    }
                }
            } catch {
                self.logger.error("Request unsuccessful")
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)
    }
}
