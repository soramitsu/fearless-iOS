import Foundation
import RobinHood

class BaseStorageChildSubscription<T: StorageWrapper>: StorageChildSubscribing {
    let remoteStorageKey: Data
    let localStorageKey: String
    let logger: LoggerProtocol
    let storage: AnyDataProviderRepository<T>
    let operationManager: OperationManagerProtocol

    init(
        remoteStorageKey: Data,
        localStorageKey: String,
        storage: AnyDataProviderRepository<T>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.remoteStorageKey = remoteStorageKey
        self.localStorageKey = localStorageKey
        self.storage = storage
        self.operationManager = operationManager
        self.logger = logger
    }

    func handle(result _: Result<DataProviderChange<T>?, Error>, blockHash _: Data?) {
        logger.warning("Must be overriden after inheritance")
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        let identifier = localStorageKey

        let fetchOperation = storage.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )

        let processingOperation: BaseOperation<DataProviderChange<T>?> =
            ClosureOperation {
                let newItem: T?

                if let newData = data {
                    newItem = T(identifier: identifier, data: newData)
                } else {
                    newItem = nil
                }

                let currentItem = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                return DataProviderChange<T>
                    .change(value1: currentItem, value2: newItem)
            }

        let saveOperation = storage.saveOperation({
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            else {
                return []
            }

            if let item = update.item {
                return [item]
            } else {
                return []
            }
        }, {
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            else {
                return []
            }

            if case let .delete(identifier) = update {
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

        operationManager.enqueue(
            operations: [fetchOperation, processingOperation, saveOperation],
            in: .transient
        )
    }
}
