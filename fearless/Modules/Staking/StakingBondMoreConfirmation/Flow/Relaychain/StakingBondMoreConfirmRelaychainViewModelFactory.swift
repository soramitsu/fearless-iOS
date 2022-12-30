import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmRelaychainViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    let chainAsset: ChainAsset

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViewModel(
        account: MetaAccountModel,
        amount: Decimal,
        state _: StakingBondMoreConfirmationViewModelState,
        locale: Locale,
        priceData: PriceData?
    ) throws -> StakingBondMoreConfirmViewModel? {
        let address = account.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? ""

        let icon = try? iconGenerator.generateFromAddress(address)

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData)
        let accountViewModel = TitleMultiValueViewModel(title: account.name, subtitle: address)
        let amountViewModel = TitleMultiValueViewModel(
            title: balanceViewModel.value(for: locale).amount,
            subtitle: balanceViewModel.value(for: locale).price
        )

        return StakingBondMoreConfirmViewModel(
            accountViewModel: accountViewModel,
            amountViewModel: amountViewModel,
            collatorViewModel: nil,
            senderIcon: icon,
            amount: createStakedAmountViewModel(amount),
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
