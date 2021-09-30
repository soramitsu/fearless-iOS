import Foundation
import RobinHood
import FearlessUtils

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation(with timeout: TimeInterval) -> BaseOperation<EraStakersInfo>
}

extension EraValidatorServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        fetchInfoOperation(with: 20.0)
    }
}
