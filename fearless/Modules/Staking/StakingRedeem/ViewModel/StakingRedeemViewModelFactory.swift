import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingRedeemViewModelFactoryProtocol {
    func createRedeemViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRedeemViewModel
}

final class StakingRedeemViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    let asset: AssetModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: AssetModel) {
        self.asset = asset
    }

    func createRedeemViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRedeemViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let address = controllerItem.toAddress() ?? ""
        let icon = try iconGenerator.generateFromAddress(address)

        return StakingRedeemViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }
}
