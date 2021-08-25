import Foundation
import SoraFoundation
import BigInt

final class AnalyticsRewardDetailsViewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol {
    let chain: Chain
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var txDateFormatter = DateFormatter.txDetails

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViweModel(
        rewardModel: AnalyticsRewardDetailsModel
    ) -> LocalizableResource<AnalyticsRewardDetailsViewModel> {
        LocalizableResource { locale in
            let formatter = self.txDateFormatter.value(for: locale)
            let date = formatter.string(from: rewardModel.date)
            let reward = self.getTokenAmountText(amount: rewardModel.amount, locale: locale)

            return AnalyticsRewardDetailsViewModel(
                txHash: rewardModel.eventId,
                status: R.string.localizable.transactionStatusCompleted(preferredLanguages: locale.rLanguages),
                date: date,
                reward: reward
            )
        }
    }

    private func getTokenAmountText(amount: BigUInt, locale: Locale) -> String {
        guard
            let tokenDecimal = Decimal.fromSubstrateAmount(
                amount,
                precision: chain.addressType.precision
            )
        else { return "" }

        let tokenAmountText = balanceViewModelFactory
            .amountFromValue(tokenDecimal)
            .value(for: locale)
        return tokenAmountText
    }
}
