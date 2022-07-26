import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmParachainViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    private let chainAsset: ChainAsset
    private let iconGenerator: IconGenerating

    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        chainAsset: ChainAsset,
        iconGenerator: IconGenerating
    ) {
        self.chainAsset = chainAsset
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        account: MetaAccountModel,
        amount: Decimal,
        state: StakingBondMoreConfirmationViewModelState
    ) throws -> StakingBondMoreConfirmViewModel? {
        guard let state = state as? StakingBondMoreConfirmationParachainViewModelState else {
            return nil
        }
        let formatter = formatterFactory.createInputFormatter(for: chainAsset.assetDisplayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let address = account.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let senderIcon = try? iconGenerator.generateFromAddress(address)
        let collatorIcon = try? iconGenerator.generateFromAddress(state.candidate.address)

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: senderIcon,
            senderName: account.name,
            amount: amount,
            collatorName: state.candidate.identity?.name,
            collatorIcon: collatorIcon
        )
    }
}
