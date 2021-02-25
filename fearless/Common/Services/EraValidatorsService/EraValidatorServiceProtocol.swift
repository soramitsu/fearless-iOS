import Foundation
import RobinHood

protocol EraValidatorServiceProtocol {
    func fetchOperation(with timeout: TimeInterval) -> BaseOperation<[DyAccountInfo]>
}
