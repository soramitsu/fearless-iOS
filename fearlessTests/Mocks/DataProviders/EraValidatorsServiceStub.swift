import Foundation
@testable import fearless
import RobinHood
import SSFUtils

final class EraValidatorServiceStub: EraValidatorServiceProtocol {
    let info: EraStakersInfo

    init(info: EraStakersInfo) {
        self.info = info
    }

    func setup() {}

    func throttle() {}

    func fetchInfoOperation() -> RobinHood.BaseOperation<EraStakersInfo> {
        return RobinHood.BaseOperation<EraStakersInfo>.createWithResult(info)
    }
}

extension EraValidatorServiceStub {
    static func westendStub() -> EraValidatorServiceProtocol {
        let info = EraStakersInfo(activeEra: 3131, validators: WestendStub.eraValidators)
        return EraValidatorServiceStub(info: info)
    }
}
