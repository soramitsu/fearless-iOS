import Foundation
import SoraFoundation
import CommonWallet
import SSFModels

final class StakingAmountRelaychainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.chainAsset = chainAsset
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
            calculator: calculator, rewardAssetPrice: relaychainViewModelState.rewardAssetPrice
        )

        let feeViewModel = buildFeeViewModel(
            viewModelState: relaychainViewModelState,
            priceData: priceData
        )

        return StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: rewardDestinationViewModel,
            feeViewModel: feeViewModel,
            inputViewModel: nil,
            continueAvailable: relaychainViewModelState.continueAvailable
        )
    }

    func buildSelectRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?,
        rewardAssetPrice: PriceData?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingAmountRelaychainViewModelState else {
            return nil
        }

        let reward: CalculatedReward?
        let price = rewardAssetPrice ?? priceData

        if let calculator = calculator {
            let restake = calculator.calculatorReturn(
                isCompound: true,
                period: .year,
                type: .max()
            )

            let payout = calculator.calculatorReturn(
                isCompound: false,
                period: .year,
                type: .max()
            )

            let amount = viewModelState.amount ?? 1.0

            let rewardAssetRate = calculator.rewardAssetRate
            let restakeReturnAmount = restake * amount * rewardAssetRate
            let payoutReturnAmount = payout * amount * rewardAssetRate

            reward = CalculatedReward(
                restakeReturn: restakeReturnAmount,
                restakeReturnPercentage: restake,
                payoutReturn: payoutReturnAmount,
                payoutReturnPercentage: payout
            )
        } else {
            reward = nil
        }

        switch viewModelState.rewardDestination {
        case .restake:
            return rewardDestViewModelFactory.createRestake(
                from: reward,
                priceData: price
            )
        case .payout:
            if let payoutAccount = viewModelState.payoutAccount,
               let address = payoutAccount.toAddress() {
                return try rewardDestViewModelFactory
                    .createPayout(
                        from: reward,
                        priceData: price,
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
