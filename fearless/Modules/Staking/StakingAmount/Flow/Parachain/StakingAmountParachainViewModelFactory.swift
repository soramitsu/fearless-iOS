import Foundation
import SoraFoundation
import SSFUtils

final class StakingAmountParachainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let accountViewModelFactory: AccountViewModelFactoryProtocol
    let wallet: MetaAccountModel

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.accountViewModelFactory = accountViewModelFactory
        self.wallet = wallet
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
            inputViewModel: nil,
            continueAvailable: parachainViewModelState.continueAvailable
        )
    }

    private func buildFeeViewModel(
        viewModelState: StakingAmountParachainViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
    }

    func buildYourRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) -> LocalizableResource<YourRewardDestinationViewModel>? {
        guard let parachainViewModelState = viewModelState as? StakingAmountParachainViewModelState else {
            return nil
        }

        let address = parachainViewModelState.wallet.fetch(for: parachainViewModelState.chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let reward: CalculatedReward?

        if let calculator = calculator {
            let restake = calculator.calculatorReturn(
                isCompound: true,
                period: .year,
                type: .avg
            )

            let payout = calculator.calculatorReturn(
                isCompound: false,
                period: .year,
                type: .avg
            )

            let curAmount = viewModelState.amount ?? 0.0
            reward = CalculatedReward(
                restakeReturn: restake * curAmount,
                restakeReturnPercentage: restake,
                payoutReturn: payout * curAmount,
                payoutReturnPercentage: payout
            )
        } else {
            reward = nil
        }

        let payoutViewModel = try? rewardDestViewModelFactory.createPayout(
            from: reward,
            priceData: priceData,
            address: address,
            title: address
        )

        return LocalizableResource { [unowned self] locale in
            let accountViewModel = AccountViewModel(
                title: R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages),
                name: wallet.name,
                icon: nil,
                image: R.image.iconBirdGreen()
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
