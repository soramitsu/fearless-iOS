import Foundation
import RobinHood

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain)
}

protocol EraValidatorProviderProtocol {
    func fetchInfoOperation(with timeout: TimeInterval) -> BaseOperation<EraStakersInfo>
}

extension EraValidatorProviderProtocol {
    func fetchInfoOperation(with timeout: TimeInterval = 20.0) -> BaseOperation<EraStakersInfo> {
        fetchInfoOperation(with: timeout)
    }
}
