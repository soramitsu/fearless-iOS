import Foundation
import SoraFoundation
import CommonWallet

final class StakingAmountRelaychainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol

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
        calculator: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel? {
        guard let relaychainViewModelState = viewModelState as? StakingAmountRelaychainViewModelState else {
            return nil
        }

        let rewardDestinationViewModel = try? buildSelectRewardDestinationViewModel(
            viewModelState: relaychainViewModelState,
            priceData: priceData,
            calculator: calculator
        )

        let feeViewModel = buildFeeViewModel(
            viewModelState: relaychainViewModelState,
            priceData: priceData
        )

        return StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: rewardDestinationViewModel,
            feeViewModel: feeViewModel,
            inputViewModel: nil
        )
    }

    func buildSelectRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingAmountRelaychainViewModelState else {
            return nil
        }

        let reward: CalculatedReward?

        if let calculator = calculator {
            let restake = calculator.calculateMaxReturn(
                isCompound: true,
                period: .year
            )

            let payout = calculator.calculateMaxReturn(
                isCompound: false,
                period: .year
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

        switch viewModelState.rewardDestination {
        case .restake:
            return rewardDestViewModelFactory.createRestake(
                from: reward,
                priceData: priceData
            )
        case .payout:
            if let payoutAccount = viewModelState.payoutAccount,
               let address = payoutAccount.toAddress() {
                return try rewardDestViewModelFactory
                    .createPayout(
                        from: reward,
                        priceData: priceData,
                        address: address,
                        title: (try? payoutAccount.toDisplayAddress().username) ?? address
                    )
            }
        }

        return nil
    }

    private func buildFeeViewModel(
        viewModelState: StakingAmountRelaychainViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
    }
}
