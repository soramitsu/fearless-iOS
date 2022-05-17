import Foundation
import RobinHood

protocol RewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol>
}
