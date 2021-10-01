import Foundation

final class StakingSharedState {
    let settings: StakingAssetSettings
    private(set) var eraValidatorService: EraValidatorServiceProtocol
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol
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

    func replaceEraValidatorService(_ newService: EraValidatorServiceProtocol) {
        eraValidatorService = newService
    }

    func replaceRewardCalculatorService(_ newService: RewardCalculatorServiceProtocol) {
        rewardCalculationService = newService
    }
}
