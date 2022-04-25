import Foundation
import RobinHood

class BaseService {
    let operationManager: OperationManagerProtocol

    init(operationManager: OperationManagerProtocol) {
        self.operationManager = operationManager
    }
}
