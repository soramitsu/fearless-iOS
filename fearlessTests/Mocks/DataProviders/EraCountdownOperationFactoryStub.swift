import Foundation
@testable import fearless
import RobinHood

struct EraCountdownOperationFactoryStub: EraCountdownOperationFactoryProtocol {

    let eraCountdown: EraCountdown

    func fetchCountdownOperationWrapper() -> CompoundOperationWrapper<EraCountdown> {
        CompoundOperationWrapper.createWithResult(eraCountdown)
    }
}

extension EraCountdown {
    static var testStub: EraCountdown {
        EraCountdown(
            activeEra: 2541,
            currentEra: 2541,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 14538,
            currentSessionIndex: 14538,
            currentSlot: 271216483,
            genesisSlot: 262493679,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }
}
