import Foundation
@testable import fearless
import RobinHood
import SSFModels

final class RewardCalculatorServiceStub: RewardCalculatorServiceProtocol {
    let engine: RewardCalculatorEngineProtocol

    init(engine: RewardCalculatorEngineProtocol) {
        self.engine = engine
    }

    func update(to chain: SSFModels.Chain) {}

    func setup() {}

    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation { self.engine }
    }
}
