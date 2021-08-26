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

        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        highlightPerTapEnabled = false
        dragEnabled = false
        maxVisibleCount = 40

        xAxis.gridLineDashLengths = [2.5, 2.5]
        xAxis.gridLineDashPhase = 0
        xAxis.gridColor = UIColor.white.withAlphaComponent(0.64)
        xAxis.labelFont = .p3Paragraph
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisFormmater

        leftAxis.labelCount = 2
        leftAxis.valueFormatter = DefaultAxisValueFormatter(formatter: formatter)
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)
        leftAxis.axisMinimum = 0

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
            ChartDataEntry(x: Double(index), y: amount)
        }

        let dataSet = LineChartDataSet(entries: dataEntries)
        dataSet.mode = .cubicBezier
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
