import Foundation
import RobinHood

final class OperationManagerFacade {
    static let sharedQueue = OperationQueue()
    static let sharedManager = OperationManager(operationQueue: sharedQueue)
}
