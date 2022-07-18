import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmRelaychainViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let asset: AssetModel
    let chain: ChainModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

    init(
        asset: AssetModel,
        chain: ChainModel,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.chain = chain
        self.iconGenerator = iconGenerator
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

        let icon = try? iconGenerator.generateFromAddress(address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: account.name,
            amount: amount,
            collatorName: nil,
            collatorIcon: nil
        )
    }
}
