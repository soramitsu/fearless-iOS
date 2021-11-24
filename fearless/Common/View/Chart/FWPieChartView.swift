import UIKit
import Charts

protocol FWPieChartViewDelegate: AnyObject {
    func didSelectSegment(index: Int)
    func didUnselect()
}

protocol FWPieChartViewProtocol {
    func setAmounts(segmentValues: [Double], inactiveSegmentValue: Double?, animated: Bool)
    func setCenterText(_ text: NSAttributedString)
    func highlightSegment(index: Int)
}

final class FWPieChartView: PieChartView {
    weak var chartDelegate: FWPieChartViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        drawEntryLabelsEnabled = false
        rotationEnabled = false
        holeRadiusPercent = 0.85
        holeColor = .clear
        drawEntryLabelsEnabled = false
        usePercentValuesEnabled = false
        legend.enabled = false
        noDataText = ""
        centerTextRadiusPercent = 0.85
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWPieChartView: FWPieChartViewProtocol {
    func setAmounts(segmentValues: [Double], inactiveSegmentValue: Double?, animated: Bool) {
        clear()
        let entries = segmentValues.enumerated().map { index, value in
            PieChartDataEntry(value: value, data: index)
        }

        let set = PieChartDataSet(entries: entries)
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 4

        set.colors = segmentValues.map { _ in R.color.colorAccent()! }

        let data = PieChartData(dataSet: set)
        if let inactiveSegmentValue = inactiveSegmentValue {
            set.append(PieChartDataEntry(value: inactiveSegmentValue, data: entries.count))
            set.colors.append(R.color.colorDarkGray()!)
            set.selectionShift = 10
        }

        self.data = data
        if animated {
            animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
        }
    }

    func setCenterText(_ text: NSAttributedString) {
        centerAttributedText = text
    }

    func highlightSegment(index: Int) {
        highlightValue(x: Double(index), dataSetIndex: 0, dataIndex: index, callDelegate: true)
    }
}

extension FWPieChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        if let index = entry.data as? Int {
            chartDelegate?.didSelectSegment(index: index)
        }
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        chartDelegate?.didUnselect()
    }
}
