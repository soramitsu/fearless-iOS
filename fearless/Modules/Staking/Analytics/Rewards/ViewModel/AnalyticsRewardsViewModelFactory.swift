import BigInt
import SoraFoundation

final class AnalyticsRewardsViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsViewModelFactoryProtocol {
    override func createSections(
        rewardsData: [SubqueryRewardItemData],
        locale: Locale
    ) -> [AnalyticsRewardSection] {
        let formatter = DateFormatter.txHistory.value(for: locale)
        let dateTitleFormatter = DateFormatter()
        dateTitleFormatter.locale = locale
        dateTitleFormatter.dateFormat = "MMM d"

        let groupedByDay = rewardsData
            .groupedBy(dateComponents: [.year, .month, .day])
        let sortedByDay: [(Date, [SubqueryRewardItemData])] = groupedByDay.keys
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
                        addressOrName: R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages),
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

protocol Dated {
    var date: Date { get }
}

extension Array where Element: Dated {
    func groupedBy(dateComponents: Set<Calendar.Component>) -> [Date: [Element]] {
        let initial: [Date: [Element]] = [:]
        let groupedByDateComponents = reduce(into: initial) { acc, cur in
            let components = Calendar.current.dateComponents(dateComponents, from: cur.date)
            let date = Calendar.current.date(from: components)!
            let existing = acc[date] ?? []
            acc[date] = existing + [cur]
        }

        return groupedByDateComponents
    }
}

extension SubqueryRewardItemData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
