import Foundation

struct AnalyticsValidatorsViewModel {
    let pieChartSegmentValues: [Double]
    let pieChartInactiveSegment: InactiveSegment?
    let chartCenterText: NSAttributedString
    let listTitle: String
    let validators: [AnalyticsValidatorItemViewModel]
    let selectedPage: AnalyticsValidatorsPage
}

extension AnalyticsValidatorsViewModel {
    struct InactiveSegment {
        let percents: Double
        let eraCount: Int
    }
}
