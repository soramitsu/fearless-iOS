import Foundation

final class StakingSharedState {
    let settings: StakingAssetSettings
    private(set) var eraValidatorService: EraValidatorServiceProtocol
    private(set) var rewardCalculationService: RewardCalculatorServiceProtocol
    let relaychainStakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol

    init(
        settings: StakingAssetSettings,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        relaychainStakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    ) {
        self.settings = settings
        self.eraValidatorService = eraValidatorService
        self.rewardCalculationService = rewardCalculationService
        self.relaychainStakingLocalSubscriptionFactory = relaychainStakingLocalSubscriptionFactory
    }

    func replaceEraValidatorService(_ newService: EraValidatorServiceProtocol) {
        eraValidatorService = newService
    }

    func replaceRewardCalculatorService(_ newService: RewardCalculatorServiceProtocol) {
        rewardCalculationService = newService
    }
}
