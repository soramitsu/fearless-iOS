import Foundation

struct AnalyticsValidatorsViewModel {
    let pieChartSegmentValues: [Double]
    let pieChartInactiveSegmentValue: Double?
    let chartCenterText: NSAttributedString
    let listTitle: String
    let validators: [AnalyticsValidatorItemViewModel]
    let selectedPage: AnalyticsValidatorsPage
}
