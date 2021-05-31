import Foundation
import SoraKeystore
import BigInt

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol
    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        chain: Chain
    ) -> ChartData
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    init(primitiveFactory: WalletPrimitiveFactoryProtocol) {
        self.primitiveFactory = primitiveFactory
    }

    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )
    }

    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType
        )
    }

    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        chain: Chain
    ) -> ChartData {
        let onlyRewards = data.filter { itemData in
            let change = RewardChange(rawValue: itemData.eventId)
            return change == .reward
        }
        let filteredByPeriod = onlyRewards
            .filter { itemData in
                itemData.timestamp >= period.timestampInterval.0 &&
                    itemData.timestamp <= period.timestampInterval.1
            }
            .sorted(by: { $0.timestamp > $1.timestamp })

        let amounts = filteredByPeriod.map { rewardItem -> Double in
            guard
                let amountValue = BigUInt(rewardItem.amount),
                let decimal = Decimal.fromSubstrateAmount(amountValue, precision: chain.addressType.precision)
            else { return 0.0 }
            return Double(truncating: decimal as NSNumber)
        }
        return ChartData(amounts: amounts)
    }
}
