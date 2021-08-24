import SoraFoundation

struct AnalyticsRewardsViewModel: AnalyticsBaseViewModel {
    let chartData: ChartData
    let summaryViewModel: AnalyticsSummaryRewardViewModel
    let periodViewModel: AnalyticsPeriodViewModel
    let sections: [AnalyticsRewardSection]
    let locale: Locale
}

extension AnalyticsRewardsViewModel {
    var isEmpty: Bool {
        sections.isEmpty
    }
}
