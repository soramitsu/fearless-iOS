import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

final class StakingRedeemConfirmationPoolViewModelFactory: StakingRedeemConfirmationViewModelFactoryProtocol {
    private let asset: AssetModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private var iconGenerator: IconGenerating
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        asset: AssetModel,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    func buildViewModel(viewModelState: StakingRedeemConfirmationViewModelState) -> StakingRedeemConfirmationViewModel? {
        guard let poolViewModelState = viewModelState as? StakingRedeemConfirmationPoolViewModelState else {
            return nil
        }

        guard let era = poolViewModelState.activeEra,
              let redeemable = poolViewModelState.stakeInfo?.redeemable(inEra: era) else {
            return nil
        }

        let redeemableDecimal = Decimal.fromSubstrateAmount(
            redeemable,
            precision: Int16(asset.precision)
        ) ?? 0.0

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: redeemableDecimal as NSNumber) ?? ""
        }

        let address = poolViewModelState.address ?? ""
        let senderIcon = try? iconGenerator.generateFromAddress(address)
        let title = LocalizableResource { locale in
            R.string.localizable.stakingRedeem(preferredLanguages: locale.rLanguages)
        }

        return StakingRedeemConfirmationViewModel(
            senderAddress: address,
            senderIcon: senderIcon,
            senderName: poolViewModelState.wallet.fetch(for: poolViewModelState.chainAsset.chain.accountRequest())?.name,
            stakeAmountViewModel: createStakedAmountViewModel(redeemableDecimal),
            amountString: amount,
            title: title,
            collatorName: nil,
            collatorIcon: nil
        )
    }

    func buildAssetViewModel(
        viewModelState: StakingRedeemConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let poolViewModelState = viewModelState as? StakingRedeemConfirmationPoolViewModelState else {
            return nil
        }

        guard let era = poolViewModelState.activeEra,
              let redeemable = poolViewModelState.stakeInfo?.redeemable(inEra: era) else {
            return nil
        }

        let redeemableDecimal = Decimal.fromSubstrateAmount(
            redeemable,
            precision: Int16(asset.precision)
        ) ?? 0.0

        return balanceViewModelFactory.createAssetBalanceViewModel(
            redeemableDecimal,
            balance: redeemableDecimal,
            priceData: priceData
        )
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { _ in
            []
        }
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: asset.displayInfo)

        let iconViewModel = asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingUnstakeAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
