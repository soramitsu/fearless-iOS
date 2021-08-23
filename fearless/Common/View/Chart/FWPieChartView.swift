import UIKit
import Charts

protocol FWPieChartViewProtocol {
    func setAmounts(segmentValues: [Double], inactiveSegmentValue: Double?)
    func setCenterText(_ text: NSAttributedString)
}

final class FWPieChartView: PieChartView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        drawEntryLabelsEnabled = false
        holeRadiusPercent = 0.85
        holeColor = .clear
        drawEntryLabelsEnabled = false
        usePercentValuesEnabled = false
        legend.enabled = false
        highlightPerTapEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWPieChartView: FWPieChartViewProtocol {
    func setAmounts(segmentValues: [Double], inactiveSegmentValue: Double?) {
        let entries = segmentValues.map { PieChartDataEntry(value: $0) }

        let set = PieChartDataSet(entries: entries)
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 4

        set.colors = segmentValues.map { _ in R.color.colorAccent()! }

        let data = PieChartData(dataSet: set)
        if let inactiveSegmentValue = inactiveSegmentValue {
            set.append(PieChartDataEntry(value: inactiveSegmentValue))
            set.colors.append(R.color.colorDarkGray()!)
        }
        self.data = data
        animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
    }

    func setCenterText(_ text: NSAttributedString) {
        centerAttributedText = text
    }
}
