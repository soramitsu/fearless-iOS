import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedDefaultQueue = OperationQueue()

    static let runtimeBuildingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        return operationQueue
    }()

    static let sharedManager = OperationManager(operationQueue: sharedDefaultQueue)
}
