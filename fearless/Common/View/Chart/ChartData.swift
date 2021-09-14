import Foundation

struct ChartAmount: Equatable {
    let value: Double
    let selected: Bool
    let filled: Bool
}

struct ChartData: Equatable {
    let amounts: [ChartAmount]
    let xAxisValues: [String]
    let bottomYValue: String
    let averageAmountValue: Double
    let averageAmountText: String?
    let animate: Bool
}
