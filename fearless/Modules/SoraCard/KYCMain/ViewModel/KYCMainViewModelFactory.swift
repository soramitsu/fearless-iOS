import Foundation

protocol KYCMainViewModelFactoryProtocol {
    func buildViewModel(from data: KYCMainData, locale: Locale) -> KYCMainViewModel
}

final class KYCMainViewModelFactory: KYCMainViewModelFactoryProtocol {
    func buildViewModel(from data: KYCMainData, locale: Locale) -> KYCMainViewModel {
        var balanceText: String
        var hasEnoughBalance: Bool = false
        if data.hasFreeAttempts {
            switch data.freeAttemptBalanceState {
            case .hasEnough:
                balanceText = R.string.localizable.detailsEnoughXorDesription(preferredLanguages: locale.rLanguages)
                hasEnoughBalance = true
            case let .missingBalance(xor, fiat):
                let fiatBalanceLeftText = NumberFormatter.fiat.stringFromDecimal(xor) ?? ""
                let xorBalanceLeftText = NumberFormatter.polkaswapBalance.stringFromDecimal(fiat) ?? ""
                balanceText = R.string.localizable.detailsNeedXorDesription(
                    xorBalanceLeftText,
                    fiatBalanceLeftText,
                    preferredLanguages: locale.rLanguages
                )
                hasEnoughBalance = false
            }
        } else {
            balanceText = R.string.localizable.soraCardNoFreeAttempts(preferredLanguages: locale.rLanguages)
        }
        return KYCMainViewModel(
            percentage: data.percentage,
            title: balanceText,
            hasFreeAttempts: data.hasFreeAttempts,
            hasEnoughBalance: hasEnoughBalance
        )
    }
}
