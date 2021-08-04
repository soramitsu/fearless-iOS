import Foundation
import RobinHood

protocol StakingDurationFetching {
    func fetchStakingDuration(
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    )
}

extension StakingDurationFetching {
    func fetchStakingDuration(
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    ) {
        let operationWrapper = operationFactory.createDurationOperation(from: runtimeCodingService)

        operationWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operationWrapper.targetOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}
