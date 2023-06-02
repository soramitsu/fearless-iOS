import Foundation
import SoraFoundation
import SSFUtils

final class StakingRedeemConfirmationRelaychainViewModelFactory: StakingRedeemConfirmationViewModelFactoryProtocol {
    let asset: AssetModel
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

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
        guard let relaychainViewModelState = viewModelState as? StakingRedeemConfirmationRelaychainViewModelState,
              let era = relaychainViewModelState.activeEra,
              let redeemable = relaychainViewModelState.stakingLedger?.redeemable(inEra: era),
              let redeemableDecimal = Decimal.fromSubstrateAmount(
                  redeemable,
                  precision: Int16(asset.precision)
              ) else {
            return nil
        }

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: redeemableDecimal as NSNumber) ?? ""
        }

        let address = relaychainViewModelState.controller?.toAddress() ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)
        let title = LocalizableResource { locale in
            R.string.localizable.commonConfirmTitle(preferredLanguages: locale.rLanguages)
        }

        return StakingRedeemConfirmationViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: relaychainViewModelState.controller?.name,
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
        guard let relaychainViewModelState = viewModelState as? StakingRedeemConfirmationRelaychainViewModelState,
              let era = relaychainViewModelState.activeEra,
              let redeemable = relaychainViewModelState.stakingLedger?.redeemable(inEra: era),
              let redeemableDecimal = Decimal.fromSubstrateAmount(
                  redeemable,
                  precision: Int16(asset.precision)
              ) else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            redeemableDecimal,
            balance: redeemableDecimal,
            priceData: priceData
        )
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { _ in
            [TitleIconViewModel]()
        }
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: asset.displayInfo, usageCase: .detailsCrypto)

        let iconViewModel = asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { [weak self] locale in
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

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.asset.color
            )
        }
    }
}
