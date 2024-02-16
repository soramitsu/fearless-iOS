import Foundation
import RobinHood

protocol StorageNetworkWorkerFactory {
    func buildNetworkWorker(operationManager: OperationManagerProtocol) -> StorageNetworkWorker
}

final class BaseStorageNetworkWorkerFactory: StorageNetworkWorkerFactory {
    func buildNetworkWorker(operationManager: OperationManagerProtocol) -> StorageNetworkWorker {
        OperationStorageNetworkWorker(operationManager: operationManager)
    }
}
