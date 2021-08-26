import SoraFoundation

struct AnalyticsRewardsViewModel: AnalyticsBaseViewModel {
    let chartData: ChartData
    let summaryViewModel: AnalyticsSummaryRewardViewModel
    let selectedPeriod: AnalyticsPeriod
    let sections: [AnalyticsRewardSection]
    let emptyListDescription: String
}

extension AnalyticsRewardsViewModel {
    var isEmpty: Bool {
        sections.isEmpty
    }
}
