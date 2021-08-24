import SoraFoundation

struct AnalyticsRewardsViewModel: AnalyticsBaseViewModel {
    let chartData: ChartData
    let summaryViewModel: AnalyticsSummaryRewardViewModel
    let periodViewModel: AnalyticsPeriodViewModel
    let sections: [AnalyticsRewardSection]
    let emptyListDescription: String
}

extension AnalyticsRewardsViewModel {
    var isEmpty: Bool {
        sections.isEmpty
    }
}
