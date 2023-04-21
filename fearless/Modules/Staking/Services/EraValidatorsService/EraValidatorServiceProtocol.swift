import Foundation
import RobinHood
import SSFUtils

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo>
}
