import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        account: MetaAccountModel,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel
}

final class StakingBondMoreConfirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let asset: AssetModel
    let chain: ChainModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        asset: AssetModel,
        chain _: ChainModel
    ) {
        self.asset = asset
    }

    func createViewModel(
        account: MetaAccountModel,
        amount: Decimal
    ) throws -> StakingBondMoreConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let address = account.fetch(for: chain.accountRequest())?.toAddress() ?? ""

        let icon = try iconGenerator.generateFromAddress(address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: account.name,
            amount: amount
        )
    }
}
