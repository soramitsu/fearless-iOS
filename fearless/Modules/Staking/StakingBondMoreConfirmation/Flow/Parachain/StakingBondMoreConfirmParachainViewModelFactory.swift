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

        let address = account.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let senderIcon = try? iconGenerator.generateFromAddress(address)
        let collatorIcon = try? iconGenerator.generateFromAddress(state.candidate.address)

        let formatter = formatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        let amountString = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(amount) ?? ""
        }

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: senderIcon,
            senderName: account.name,
            amount: createStakedAmountViewModel(amount),
            amountString: amountString,
            collatorName: state.candidate.identity?.name,
            collatorIcon: collatorIcon
        )
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)

        let iconViewModel = chainAsset.assetDisplayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingStakeMoreAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite(),
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
