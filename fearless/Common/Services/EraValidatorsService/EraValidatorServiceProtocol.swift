import Foundation
import RobinHood

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain, engine: JSONRPCEngine)
    func fetchInfoOperation(with timeout: TimeInterval) -> BaseOperation<EraStakersInfo>
}

extension EraValidatorServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        fetchInfoOperation(with: 20.0)
    }
}
