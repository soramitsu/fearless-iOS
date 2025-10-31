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

    // No-op in stub; signature removed to avoid dependency on Chain type

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let op: ClosureOperation<EraStakersInfo> = ClosureOperation { self.info }
        return op
    }
}

extension EraValidatorServiceStub {
    static func westendStub() -> EraValidatorServiceProtocol {
        let info = EraStakersInfo(activeEra: 3131, validators: WestendStub.eraValidators)
        return EraValidatorServiceStub(info: info)
    }
}
