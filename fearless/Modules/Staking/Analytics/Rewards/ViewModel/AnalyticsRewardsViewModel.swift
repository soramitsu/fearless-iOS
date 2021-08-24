import SoraFoundation

struct AnalyticsRewardsViewModel: AnalyticsRewardsBaseViewModel {
    let chartData: ChartData
    let summaryViewModel: AnalyticsSummaryRewardViewModel
    let periodViewModel: AnalyticsPeriodViewModel
    let rewardSections: [AnalyticsRewardSection]
    let locale: Locale
}

extension AnalyticsRewardsViewModel {
    var isEmpty: Bool {
        rewardSections.isEmpty
    }
}
