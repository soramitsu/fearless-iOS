import Foundation
import RobinHood

class BaseStorageChildSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let localStorageKey: String
    let logger: LoggerProtocol
    let eventCenter: EventCenterProtocol
    let storage: AnyDataProviderRepository<ChainStorageItem>
    let operationManager: OperationManagerProtocol

    init(remoteStorageKey: Data,
         localStorageKey: String,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol,
         eventCenter: EventCenterProtocol) {
        self.remoteStorageKey = remoteStorageKey
        self.localStorageKey = localStorageKey
        self.storage = storage
        self.operationManager = operationManager
        self.logger = logger
        self.eventCenter = eventCenter
    }

    func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.warning("Must be overriden after inheritance")
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        let identifier = localStorageKey

        let fetchOperation = storage.fetchOperation(by: identifier,
                                                    options: RepositoryFetchOptions())

        let processingOperation: BaseOperation<DataProviderChange<ChainStorageItem>?> =
            ClosureOperation {
            let newItem: ChainStorageItem?

            if let newData = data {
                newItem = ChainStorageItem(identifier: identifier, data: newData)
            } else {
                newItem = nil
            }

            let currentItem = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return DataProviderChange<ChainStorageItem>
                .change(value1: currentItem, value2: newItem)
        }

        let saveOperation = storage.saveOperation({
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            if let item = update.item {
                return [item]
            } else {
                return []
            }
        }, {
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            if case .delete(let identifier) = update {
                return [identifier]
            } else {
                return []
            }
        })

        processingOperation.addDependency(fetchOperation)
        saveOperation.addDependency(processingOperation)

        saveOperation.completionBlock = { [weak self] in
            guard let changeResult = processingOperation.result else {
                return
            }

            self?.handle(result: changeResult, blockHash: blockHash)
        }

        operationManager.enqueue(operations: [fetchOperation, processingOperation, saveOperation],
                                 in: .sync)
    }

}
