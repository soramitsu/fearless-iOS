import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel
}

final class StakingBondMoreConfirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let asset: WalletAsset

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount
        )
    }
}
