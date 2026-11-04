import Foundation
@testable import fearless
import Cuckoo

extension MockStakingServiceFactoryProtocol {
    func apply(
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculatorService: RewardCalculatorServiceProtocol
    ) -> MockStakingServiceFactoryProtocol {
        stub(self) { stub in
            stub.createEraValidatorService(for: any()).thenReturn(eraValidatorService)
            stub.createRewardCalculatorService(
                for: any(),
                assetPrecision: any(),
                validatorService: any()
            ).thenReturn(rewardCalculatorService)
        }

        return self
    }
}
