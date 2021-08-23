import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
    override func createSections(
        rewardsData: [SubqueryStakeChangeData],
        locale: Locale
    ) -> [AnalyticsRewardSection] {
        let formatter = DateFormatter.txHistory.value(for: locale)
        let dateTitleFormatter = DateFormatter()
        dateTitleFormatter.locale = locale
        dateTitleFormatter.dateFormat = "MMM d"

        let groupedByDay = rewardsData
            .groupedBy(dateComponents: [.year, .month, .day])
        let sortedByDay: [(Date, [SubqueryStakeChangeData])] = groupedByDay.keys
            .map { (key: Date) in
                (key, groupedByDay[key]!)
            }
            .sorted(by: { $0.0 > $1.0 })

        return sortedByDay
            .map { date, rewards in
                let items: [AnalyticsRewardsItemViewModel] = rewards.compactMap { itemData in
                    guard
                        let tokenDecimal = Decimal.fromSubstrateAmount(
                            itemData.amount,
                            precision: self.chain.addressType.precision
                        )
                    else { return nil }

                    let tokenAmountText = balanceViewModelFactory
                        .amountFromValue(tokenDecimal)
                        .value(for: locale)

                    let txDate = Date(timeIntervalSince1970: TimeInterval(itemData.timestamp))
                    let txTimeText = formatter.string(from: txDate)
                    let subtitle = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)

                    return AnalyticsRewardsItemViewModel(
                        addressOrName: itemData.type.title(for: locale),
                        daysLeftText: .init(string: subtitle),
                        tokenAmountText: "+\(tokenAmountText)",
                        usdAmountText: txTimeText
                    )
                }

                let title = dateTitleFormatter.string(from: date).uppercased()

                return AnalyticsRewardSection(
                    title: title,
                    items: items
                )
            }
    }
}

extension SubqueryStakeChangeData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
