import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
    override func getHistoryItemTitle(data: SubqueryStakeChangeData, locale: Locale) -> String {
        data.type.title(for: locale)
    }
}

extension SubqueryStakeChangeData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
