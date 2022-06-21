import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import IrohaCrypto

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel
}

final class StakingRebondConfirmationViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    let asset: AssetModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

    init(
        asset: AssetModel,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal
    ) throws -> StakingRebondConfirmationViewModel {
        let addressFactory = SS58AddressFactory()
        let address = (try? addressFactory.address(fromAccountId: controllerItem.accountId, type: controllerItem.addressPrefix)) ?? ""

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let icon = try iconGenerator.generateFromAddress(address)

        return StakingRebondConfirmationViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }
}
