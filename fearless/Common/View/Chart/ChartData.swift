import Foundation

struct ChartAmount {
    let value: Double
    let selected: Bool
    let filled: Bool
}

struct ChartData {
    let amounts: [ChartAmount]
    let xAxisValues: [String]
    let bottomYValue: String
    let averageAmountValue: Double
    let averageAmountText: String?
    let animate: Bool
}
