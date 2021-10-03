import Foundation
import RobinHood

// TODO: Remove after refactoring
final class RewardCalculatorFacade {
    static let sharedService = MockRewardCalculatorService()
}

final class MockRewardCalculatorService: RewardCalculatorServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
    }

    func setup() {}

    func throttle() {}
}
