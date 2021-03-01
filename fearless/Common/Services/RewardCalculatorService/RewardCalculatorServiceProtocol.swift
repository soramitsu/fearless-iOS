import Foundation
import RobinHood

protocol RewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain)
    func fetchCalculatorOperation(with timeout: TimeInterval) -> BaseOperation<RewardCalculatorEngineProtocol>
}

extension RewardCalculatorServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        fetchCalculatorOperation(with: 20.0)
    }
}
