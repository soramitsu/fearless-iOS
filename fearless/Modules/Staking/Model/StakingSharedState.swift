import Foundation

final class StakingSharedState {
    let settings: StakingAssetSettings
    private(set) var eraValidatorService: EraValidatorServiceProtocol
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol
    let relaychainStakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        relaychainStakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol,
        parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.relaychainStakingLocalSubscriptionFactory = relaychainStakingLocalSubscriptionFactory
        self.stakingAnalyticsLocalSubscriptionFactory = stakingAnalyticsLocalSubscriptionFactory
        self.parachainStakingLocalSubscriptionFactory = parachainStakingLocalSubscriptionFactory
    }

    func replaceEraValidatorService(_ newService: EraValidatorServiceProtocol) {
        eraValidatorService = newService
    }

    func replaceRewardCalculatorService(_ newService: RewardCalculatorServiceProtocol) {
        rewardCalculationService = newService
    }
}
