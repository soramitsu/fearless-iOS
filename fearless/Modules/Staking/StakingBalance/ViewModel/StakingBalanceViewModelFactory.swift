import Foundation

protocol StakingBalanceViewModelFactoryProtocol {
    func createViewModel(from balanceDat: StakingBalanceData) -> StakingBalanceViewModel
}

struct StakingBalanceViewModelFactory: StakingBalanceViewModelFactoryProtocol {
    func createViewModel(from balanceData: StakingBalanceData) -> StakingBalanceViewModel {
        StakingBalanceViewModel(
            widgetViewModels: createWidgetViewModels(from: balanceData),
            unbondings: createUnbondingsViewModels(from: balanceData)
        )
    }

    func createWidgetViewModels(from balanceData: StakingBalanceData) -> [StakingBalanceWidgetViewModel] {
        let precision: Int16 = 0
        let bonded = Decimal
            .fromSubstrateAmount(
                balanceData.stakingLedger.active,
                precision: precision
            ) ?? .zero

        let unbonding = Decimal
            .fromSubstrateAmount(
                balanceData.stakingLedger.unbounding(inEra: balanceData.activeEra),
                precision: precision
            ) ?? .zero

        let redeemable = Decimal
            .fromSubstrateAmount(
                balanceData.stakingLedger.redeemable(inEra: balanceData.activeEra),
                precision: precision
            ) ?? .zero

        return [
            .init(title: "Bonded", tokenAmountText: bonded.description, usdAmountText: "$1"),
            .init(title: "Unbonding", tokenAmountText: unbonding.description, usdAmountText: "$1"),
            .init(title: "Redeemable", tokenAmountText: redeemable.description, usdAmountText: "$1")
        ]
    }

    func createUnbondingsViewModels(from balanceData: StakingBalanceData) -> [UnbondingItemViewModel] {
        let precision: Int16 = 0
        return balanceData.stakingLedger.unlocking
            .map { unbondingItem -> UnbondingItemViewModel in
                let tokenAmount = Decimal
                    .fromSubstrateAmount(
                        unbondingItem.value,
                        precision: precision
                    ) ?? .zero
                return UnbondingItemViewModel(
                    addressOrName: "Unbond",
                    daysLeftText: .init(string: "days left"),
                    tokenAmountText: tokenAmount.description,
                    usdAmountText: "10"
                )
            }
    }
}
