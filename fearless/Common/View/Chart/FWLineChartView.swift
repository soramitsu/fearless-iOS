import UIKit
import Charts

final class FWLineChartView: LineChartView {
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    let xAxisFormmater = ChartAxisFormmatter()

    weak var chartDelegate: FWChartViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        highlightPerTapEnabled = false
        maxVisibleCount = 40

        xAxis.drawGridLinesEnabled = false
        xAxis.labelFont = .p3Paragraph
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = R.color.colorStrokeGray()!
        xAxis.valueFormatter = xAxisFormmater
        xAxis.xOffset = 0

        leftAxis.labelCount = 2
        leftAxis.drawGridLinesEnabled = false
        leftAxis.valueFormatter = DefaultAxisValueFormatter(formatter: formatter)
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)

        rightAxis.enabled = false
        drawBordersEnabled = false
        minOffset = 0
        legend.enabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWLineChartView: FWChartViewProtocol {
    func setChartData(_ data: ChartData) {
        let dataEntries = data.amounts.enumerated().map { index, amount in
            ChartDataEntry(x: Double(index), y: amount.value)
        }

        let dataSet = LineChartDataSet(entries: dataEntries)
        dataSet.mode = .horizontalBezier
        dataSet.drawIconsEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawCirclesEnabled = false
        dataSet.colors = [
            R.color.colorAccent()!
        ]

        let gradientColors = [
            R.color.colorAccent()!.withAlphaComponent(0.48).cgColor,
            UIColor(red: 0.858, green: 0, blue: 1, alpha: 0.32).cgColor
        ] as CFArray
        let colorLocations: [CGFloat] = [1.0, 0.0]
        let linearGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors,
            locations: colorLocations
        )!
        dataSet.fill = Fill(linearGradient: linearGradient, angle: 90)
        dataSet.fillAlpha = 1.0
        dataSet.drawFilledEnabled = true
        let lineChartData = LineChartData(dataSet: dataSet)

        xAxisFormmater.xAxisValues = data.xAxisValues
        xAxis.labelCount = data.xAxisValues.count

        self.data = lineChartData
        animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
    }
}

extension FWLineChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        chartDelegate?.didSelectXValue(entry.x)
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        chartDelegate?.didUnselect()
    }
}
