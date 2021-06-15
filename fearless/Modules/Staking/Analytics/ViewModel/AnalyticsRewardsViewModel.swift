struct AnalyticsRewardsViewModel {
    let chartData: ChartData
    let summaryViewModel: AnalyticsSummaryRewardViewModel
    let receivedViewModel: AnalyticsSummaryRewardViewModel
    let payableViewModel: AnalyticsSummaryRewardViewModel
    let periods: [AnalyticsPeriod]
    let selectedPeriod: AnalyticsPeriod
    let periodTitle: String
    let canSelectPreviousPeriod: Bool
    let canSelectNextPeriod: Bool
}
