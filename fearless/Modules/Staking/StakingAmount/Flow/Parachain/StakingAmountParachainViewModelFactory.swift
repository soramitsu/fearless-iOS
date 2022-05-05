import Foundation

final class StakingAmountParachainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
    }

    func buildViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData _: PriceData?,
        calculator _: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel? {
        guard let parachainViewModelState = viewModelState as? StakingAmountParachainViewModelState else {
            return nil
        }

        return StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: nil,
            feeViewModel: nil,
            inputViewModel: nil
        )
    }
}
