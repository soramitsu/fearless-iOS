import Foundation
import SSFModels
import BigInt

final class CrossChainFundsPermissionViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.amountFormatterFactory = amountFormatterFactory
    }
    
    func buildViewModel(
        mode: CrossChainFundsPermissionMode,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        swap:  CrossChainSwap,
        locale: Locale
    ) -> CrossChainFundsPermissionViewModel {
        let formatter = amountFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)

        let fromAmount = swap.fromAmount.flatMap { BigUInt(string: $0) }
        let fromAmountDecimal = fromAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) }
        let amountViewModel = fromAmountDecimal.flatMap { balanceViewModelFactory.balanceFromPrice($0, priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }
        let fromViewModel = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress().flatMap { TitleMultiValueViewModel(title: wallet.name, subtitle: $0)}
        let requestFromViewModel = mode.dexTokenApproveAddress.flatMap { TitleMultiValueViewModel(title: $0, subtitle: nil) }
        let shadowColor = HexColorConverter.hexStringToUIColor(
            hex: chainAsset.asset.color
        )?.cgColor
        let iconViewModel = chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) }
        let symbolViewModel = SymbolViewModel(
            iconViewModel: iconViewModel,
            shadowColor: shadowColor
        )
        let inputAmount = fromAmountDecimal.flatMap { formatter.value(for: locale).stringFromDecimal($0) }
        let amountString = inputAmount.flatMap {
            return mode.title(amount: $0, locale: locale)
        }
        let amountAttributedString = NSMutableAttributedString(string: amountString.or(""))
        amountAttributedString.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorWhite()!.cgColor,
            range: (amountString.or("") as NSString).range(of: inputAmount.or(""))
        )
        
        return CrossChainFundsPermissionViewModel(
            amountLabelText: amountAttributedString,
            fromViewModel: fromViewModel,
            requestFromViewModel: requestFromViewModel,
            amountViewModel: amountViewModel?.value(for: locale),
            warningText: mode.warningText(for: locale),
            symbolViewModel: symbolViewModel,
            confirmButtonTitle: mode.title(amount: "", locale: locale)
        )
    }
}
