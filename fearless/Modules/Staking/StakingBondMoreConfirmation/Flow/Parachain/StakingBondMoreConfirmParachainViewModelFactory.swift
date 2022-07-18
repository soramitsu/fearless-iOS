import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmParachainViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let asset: AssetModel
    let chain: ChainModel
    let collator: ParachainStakingCandidateInfo

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

    init(
        asset: AssetModel,
        chain: ChainModel,
        iconGenerator: IconGenerating,
        collator: ParachainStakingCandidateInfo
    ) {
        self.asset = asset
        self.chain = chain
        self.iconGenerator = iconGenerator
        self.collator = collator
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

        let senderIcon = try? iconGenerator.generateFromAddress(address)
        let collatorIcon = try? iconGenerator.generateFromAddress(collator.address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: senderIcon,
            senderName: account.name,
            amount: amount,
            collatorName: collator.identity?.name,
            collatorIcon: collatorIcon
        )
    }
}
