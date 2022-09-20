import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmRelaychainViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let chainAsset: ChainAsset

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

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
        state _: StakingBondMoreConfirmationViewModelState
    ) throws -> StakingBondMoreConfirmViewModel? {
        let address = account.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let icon = try? iconGenerator.generateFromAddress(address)

        let formatter = formatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        let amountString = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(amount) ?? ""
        }

        return StakingBondMoreConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: account.name,
            amount: createStakedAmountViewModel(amount),
            amountString: amountString,
            collatorName: nil,
            collatorIcon: nil
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
