import Foundation
@testable import fearless
import RobinHood

final class RewardCalculatorServiceStub: RewardCalculatorServiceProtocol {
    let engine: RewardCalculatorEngineProtocol

    init(engine: RewardCalculatorEngineProtocol) {
        self.engine = engine
    }

    func update(to chain: Chain) {}

    func setup() {}

    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation { self.engine }
    }
}
