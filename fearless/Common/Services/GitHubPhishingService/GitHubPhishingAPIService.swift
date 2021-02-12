import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    private var operation: BaseOperation<[PhishingItem]>
    private var logger: LoggerProtocol
    private var storage: CoreDataRepository<PhishingItem, CDPhishingItem>
    private var operationManager: OperationManagerProtocol

    init(operation: BaseOperation<[PhishingItem]>,
         logger: LoggerProtocol,
         storage: CoreDataRepository<PhishingItem, CDPhishingItem>,
         operationManager: OperationManagerProtocol) {
        self.operation = operation
        self.logger = logger
        self.storage = storage
        self.operationManager = operationManager
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
        operation.cancel()
    }

    private func setupConnection() {
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
