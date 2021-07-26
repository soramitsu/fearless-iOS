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
    static var stub: EraCountdown {
        EraCountdown(
            activeEra: 0,
            eraLength: 0,
            sessionLength: 0,
            eraStartSessionIndex: 0,
            currentSessionIndex: 0,
            currentSlot: 0,
            genesisSlot: 0,
            blockCreationTime: 0,
            createdAtDate: Date()
        )
    }
}
