import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel
}

final class StakingRebondConfirmationViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    let asset: WalletAsset

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createViewModel(
        controllerItem: AccountItem,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingRebondConfirmationViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount
        )
    }
}
