import Foundation
import SoraFoundation

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
        priceData: PriceData?,
        calculator _: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel? {
        guard let parachainViewModelState = viewModelState as? StakingAmountParachainViewModelState else {
            return nil
        }

        let feeViewModel = buildFeeViewModel(
            viewModelState: parachainViewModelState,
            priceData: priceData
        )

        return StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: nil,
            feeViewModel: feeViewModel,
            inputViewModel: nil
        )
    }

    private func buildFeeViewModel(
        viewModelState: StakingAmountParachainViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
    }
}
