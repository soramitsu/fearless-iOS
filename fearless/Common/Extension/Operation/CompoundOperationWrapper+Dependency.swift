import Foundation
import RobinHood

extension CompoundOperationWrapper {
    func addDependency(operations: [Operation]) {
        allOperations.forEach { nextOperation in
            operations.forEach { prevOperation in
                nextOperation.addDependency(prevOperation)
            }
        }
    }

    func addDependency<T>(wrapper: CompoundOperationWrapper<T>) {
        addDependency(operations: wrapper.allOperations)
    }
}
