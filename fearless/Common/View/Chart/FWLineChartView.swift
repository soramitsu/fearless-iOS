import UIKit
import Charts

final class FWLineChartView: LineChartView {
    weak var chartDelegate: FWChartViewDelegate?

    let xAxisEmptyFormatter = FWXAxisEmptyValueFormatter()
    let xAxisLegend = FWXAxisChartLegendView()
    let yAxisFormatter = FWYAxisChartFormatter(hideMiddleLabels: false)

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        highlightPerTapEnabled = false
        dragYEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisEmptyFormatter

        leftAxis.labelCount = 2
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.valueFormatter = yAxisFormatter
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)

        rightAxis.enabled = false
        drawBordersEnabled = false
        minOffset = 0
        legend.enabled = false

        noDataText = ""

        addSubview(xAxisLegend)
        xAxisLegend.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(40)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWLineChartView: FWChartViewProtocol {
    func setChartData(_ data: ChartData, animated _: Bool) {
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

        xAxisLegend.setValues(data.xAxisValues)
        yAxisFormatter.bottomValueString = data.bottomYValue

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
