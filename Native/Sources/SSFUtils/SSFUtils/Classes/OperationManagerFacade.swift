import Foundation
import RobinHood

public enum OperationManagerFacade {
    public static let sharedDefaultQueue = OperationQueue()

    public static let runtimeBuildingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 50
        return operationQueue
    }()

    public static let syncQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        operationQueue.maxConcurrentOperationCount = 20
        return operationQueue
    }()

    public static let sharedManager = OperationManager(operationQueue: sharedDefaultQueue)
}
