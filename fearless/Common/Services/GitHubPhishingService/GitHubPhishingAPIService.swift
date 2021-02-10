import Foundation
import RobinHood

class GitHubPhishingAPIService: ApplicationServiceProtocol {
    lazy var endPoint: String = { return "https://polkadot.js.org/phishing/address.json" }()

    private var operation: BaseOperation<[PhishingItem]>
    private var logger: Logger
    private var storage: CoreDataRepository<PhishingItem, CDPhishingItem>

    init(operation: BaseOperation<[PhishingItem]>,
         logger: Logger,
         storage: CoreDataRepository<PhishingItem, CDPhishingItem>) {
        self.operation = operation
        self.logger = logger
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
        operation.cancel()
    }

    private func setupConnection() {
        operation.completionBlock = { [self] in
            do {
                if let phishingItems = try operation.extractResultData() {
                    let deleteOperation = storage.deleteAllOperation()
                    OperationManagerFacade.sharedManager.enqueue(operations: [deleteOperation], in: .sync)

                    for phishingItem in phishingItems {
                        let saveOperation = storage.saveOperation({ [phishingItem] }, { [] })
                        OperationManagerFacade.sharedManager.enqueue(operations: [saveOperation], in: .sync)
                    }
                }
            } catch {
                self.logger.error("Request unsuccessful")
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)
    }
}
