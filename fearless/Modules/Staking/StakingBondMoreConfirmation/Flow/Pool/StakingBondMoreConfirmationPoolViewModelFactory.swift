import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class StakingBondMoreConfirmPoolViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol {
    private let chainAsset: ChainAsset
    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var formatterFactory = AssetBalanceFormatterFactory()

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
        state: StakingBondMoreConfirmationViewModelState,
        locale: Locale,
        priceData: PriceData?
    ) -> StakingBondMoreConfirmViewModel? {
        guard state is StakingBondMoreConfirmationPoolViewModelState else {
            return nil
        }

        let address = account.fetch(for: chainAsset.chain.accountRequest())?.toAddress() ?? ""
        let senderIcon = try? iconGenerator.generateFromAddress(address)

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData, usageCase: .listCrypto)
        let accountViewModel = TitleMultiValueViewModel(title: account.name, subtitle: address)
        let amountViewModel = TitleMultiValueViewModel(
            title: balanceViewModel.value(for: locale).amount,
            subtitle: balanceViewModel.value(for: locale).price
        )

        return StakingBondMoreConfirmViewModel(
            accountViewModel: accountViewModel,
            amountViewModel: amountViewModel,
            collatorViewModel: nil,
            senderIcon: senderIcon,
            amount: createStakedAmountViewModel(amount),
            collatorIcon: nil
        )
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)

        let iconViewModel = chainAsset.assetDisplayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { [weak self] locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingStakeMoreAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.chainAsset.asset.color
            )
        }
    }
}
