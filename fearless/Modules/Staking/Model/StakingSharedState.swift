import Foundation

final class StakingSharedState {
    let settings: StakingAssetSettings
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardCalculationService: RewardCalculatorServiceProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
    }
}
