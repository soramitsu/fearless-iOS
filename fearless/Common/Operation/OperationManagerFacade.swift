import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedQueue = OperationQueue()

    static let runtimeBuildingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 8
        return operationQueue
    }()

    static let sharedManager = OperationManager(operationQueue: sharedQueue)
}
