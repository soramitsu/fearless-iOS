import Foundation

final class StakingSharedState {
    let settings: StakingAssetSettings
    private(set) var eraValidatorService: EraValidatorServiceProtocol
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.stakingAnalyticsLocalSubscriptionFactory = stakingAnalyticsLocalSubscriptionFactory
    }

    func replaceEraValidatorService(_ newService: EraValidatorServiceProtocol) {
        eraValidatorService = newService
    }

    func replaceRewardCalculatorService(_ newService: RewardCalculatorServiceProtocol) {
        rewardCalculationService = newService
    }
}
