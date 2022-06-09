import Foundation
import SoraFoundation

final class StakingAmountParachainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
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

    func buildYourRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<YourRewardDestinationViewModel>? {
        guard let parachainViewModelState = viewModelState as? StakingAmountParachainViewModelState else {
            return nil
        }

        let address = parachainViewModelState.wallet.fetch(for: parachainViewModelState.chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let reward = CalculatedReward(restakeReturn: 5, restakeReturnPercentage: 10, payoutReturn: 15, payoutReturnPercentage: 20)
        let payoutViewModel = try? rewardDestViewModelFactory.createPayout(
            from: reward,
            priceData: priceData,
            address: address,
            title: address
        )

        return LocalizableResource { [unowned self] locale in
            let accountViewModel = self.accountViewModelFactory.buildViewModel(
                title: R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages),
                address: address,
                locale: locale
            )
            return YourRewardDestinationViewModel(
                accountViewModel: accountViewModel,
                payoutAmount: payoutViewModel?.value(for: locale).rewardViewModel?.payoutAmount,
                payoutPercentage: payoutViewModel?.value(for: locale).rewardViewModel?.payoutPercentage,
                payoutPrice: payoutViewModel?.value(for: locale).rewardViewModel?.payoutPrice
            )
        }
    }
}
