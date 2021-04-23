import Foundation

protocol StakingBalanceWidgetViewModelFactoryProtocol {
    func createViewModel(from balanceDat: StakingBalanceData) -> StakingBalanceWidgetViewModel
}

struct StakingBalanceWidgetViewModelFactory: StakingBalanceWidgetViewModelFactoryProtocol {
    func createViewModel(from balanceData: StakingBalanceData) -> StakingBalanceWidgetViewModel {
        let precision: Int16 = 0
        let bonded = Decimal
            .fromSubstrateAmount(
                balanceData.bonded,
                precision: precision
            ) ?? .zero

        let unbonding = Decimal
            .fromSubstrateAmount(
                balanceData.unbonding,
                precision: precision
            ) ?? .zero

        let redeemable = Decimal
            .fromSubstrateAmount(
                balanceData.redeemable,
                precision: precision
            ) ?? .zero

        return StakingBalanceWidgetViewModel(
            title: "",
            tokemAmountText: "",
            usdAmountText: ""
        )
    }
}
