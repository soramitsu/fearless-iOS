import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingRedeemViewModelFactoryProtocol {
    func createRedeemViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingRedeemViewModel
}

final class StakingRedeemViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    let asset: WalletAsset

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createRedeemViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingRedeemViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingRedeemViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount,
            shouldResetRewardDestination: shouldResetRewardDestination
        )
    }
}
