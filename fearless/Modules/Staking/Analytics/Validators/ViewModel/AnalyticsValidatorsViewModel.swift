import Foundation

struct AnalyticsValidatorsViewModel: Equatable {
    let pieChartSegmentValues: [Double]
    let pieChartInactiveSegment: InactiveSegment?
    let chartCenterText: NSAttributedString
    let listTitle: String
    let validators: [AnalyticsValidatorItemViewModel]
    let selectedPage: AnalyticsValidatorsPage
}

extension AnalyticsValidatorsViewModel {
    struct InactiveSegment: Equatable {
        let percents: Double
        let eraCount: Int
    }
}
