import Foundation
@testable import fearless
import RobinHood

final class RewardCalculatorServiceStub: RewardCalculatorServiceProtocol {
    let engine: RewardCalculatorEngineProtocol

    init(engine: RewardCalculatorEngineProtocol) {
        self.engine = engine
    }

    // legacy API placeholder removed; protocol no longer requires chain updates

    func setup() {}

    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation { self.engine }
    }
}
