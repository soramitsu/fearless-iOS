import Foundation

struct ChartAmount {
    let value: Double
    let filled: Bool
}

struct ChartData {
    let amounts: [ChartAmount]
    let summary: [AnalyticsSummaryRewardViewModel]
    let xAxisValues: [String]
    let bottomYValue: String
}
