import Foundation
@testable import fearless
import RobinHood
import FearlessUtils

final class EraValidatorServiceStub: EraValidatorServiceProtocol {
    let info: EraStakersInfo

    init(info: EraStakersInfo) {
        self.info = info
    }

    func setup() {}

    func throttle() {}

    func update(to chain: Chain, engine: JSONRPCEngine) {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        return BaseOperation.createWithResult(info)
    }
}

extension EraValidatorServiceStub {
    static func westendStub() -> EraValidatorServiceProtocol {
        let info = EraStakersInfo(activeEra: 3131, validators: WestendStub.eraValidators)
        return EraValidatorServiceStub(info: info)
    }
}
