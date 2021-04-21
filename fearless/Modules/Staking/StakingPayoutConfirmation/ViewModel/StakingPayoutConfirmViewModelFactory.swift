import Foundation
import FearlessUtils
import CommonWallet

protocol StakingPayoutConfirmViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        with account: AccountItem,
        rewardAmount: Decimal
    ) -> [RewardDetailsRow]
}

final class StakingPayoutConfirmViewModelFactory {
    private let iconGenerator: IconGenerating
    private let asset: WalletAsset
    private let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        asset: WalletAsset,
        amountFormatterFactory: NumberFormatterFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.asset = asset
        self.amountFormatterFactory = amountFormatterFactory
    }
}

extension StakingPayoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(with _: AccountItem, rewardAmount _: Decimal) -> [RewardDetailsRow] {
        []
    }
}
