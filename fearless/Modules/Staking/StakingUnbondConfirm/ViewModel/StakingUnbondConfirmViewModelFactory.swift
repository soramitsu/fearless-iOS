import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func createUnbondConfirmViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel
}

final class StakingUnbondConfirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    let asset: WalletAsset

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createUnbondConfirmViewModel(
        controllerItem: AccountItem,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(controllerItem.address)

        return StakingUnbondConfirmViewModel(
            senderAddress: controllerItem.address,
            senderIcon: icon,
            senderName: controllerItem.username,
            amount: amount,
            shouldResetRewardDestination: shouldResetRewardDestination
        )
    }
}
