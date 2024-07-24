import Foundation
import SoraFoundation

protocol AccountStatisticsViewModelFactory {
    func buildViewModel(accountScore: AccountStatistics?, locale: Locale) -> AccountStatisticsViewModel?
}

final class AccountStatisticsViewModelFactoryImpl: AccountStatisticsViewModelFactory {
    private lazy var timeFormatter = TotalTimeFormatter()

    func buildViewModel(accountScore: AccountStatistics?, locale: Locale) -> AccountStatisticsViewModel? {
        guard let accountScore, let score = accountScore.score else {
            return nil
        }
        let rate = AccountScoreRate(from: score)
        let intScore = ((score * 100.0) as NSDecimalNumber).intValue
        let doubleScore = (5 * score as NSDecimalNumber).doubleValue

        let avgTxTime = (accountScore.stats?.averageTransactionTime).flatMap { ($0 as NSDecimalNumber).doubleValue }
        let maxTxTime = (accountScore.stats?.maxTransactionTime).flatMap { ($0 as NSDecimalNumber).doubleValue }
        let minTxTime = (accountScore.stats?.minTransactionTime).flatMap { ($0 as NSDecimalNumber).doubleValue }

        let fiatFomatter = createFiatBalanceFormatter(locale: locale)
        let dateFormatter = DateFormatter.shortDate.value(for: locale)

        let updatedText = accountScore.stats?.scoredAt.flatMap { dateFormatter.string(from: $0) }
        let nativeBalanceText = accountScore.stats?.nativeBalanceUSD.flatMap { fiatFomatter.stringFromDecimal($0) }
        let holdTokensText = accountScore.stats?.holdTokensBalanceUSD.flatMap { fiatFomatter.stringFromDecimal($0) }
        let walletAgeText = accountScore.stats?.walletAge.flatMap { "\($0) month" }
        let totalTransactionsText = accountScore.stats?.totalTransactions.flatMap { "\($0)" }
        let rejectedTransactionsText = accountScore.stats?.totalRejectedTransactions.flatMap { "\($0)" }
        let avgTransactionTimeText = avgTxTime.flatMap { try? timeFormatter.string(from: $0) }
        let maxTransactionTimeText = maxTxTime.flatMap { try? timeFormatter.string(from: $0) }
        let minTransactionTimeText = minTxTime.flatMap { try? timeFormatter.string(from: $0) }

        return AccountStatisticsViewModel(
            rating: doubleScore,
            scoreLabelText: "\(intScore)",
            rate: rate,
            addressViewText: accountScore.address,
            updatedLabelText: updatedText,
            nativeBalanceUsdLabelText: nativeBalanceText,
            holdTokensUsdLabelText: holdTokensText,
            walletAgeLabelText: walletAgeText,
            totalTransactionsLabelText: totalTransactionsText,
            rejectedTransactionsLabelText: rejectedTransactionsText,
            avgTransactionTimeLabelText: avgTransactionTimeText,
            maxTransactionTimeLabelText: maxTransactionTimeText,
            minTransactionTimeLabelText: minTransactionTimeText
        )
    }

    // MARK: Private

    private func createFiatBalanceFormatter(locale: Locale) -> LocalizableDecimalFormatting {
        AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(.defaultCurrency()), usageCase: .fiat).value(for: locale)
    }
}
