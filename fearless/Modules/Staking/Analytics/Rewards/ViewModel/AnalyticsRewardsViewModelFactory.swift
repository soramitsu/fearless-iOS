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

        return rewardsData
            .groupedBy(dateComponents: [.day])
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

                    return AnalyticsRewardsItemViewModel(
                        addressOrName: R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages),
                        daysLeftText: .init(string: R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)),
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
