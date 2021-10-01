import Foundation
import RobinHood
import FearlessUtils

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo>
}
