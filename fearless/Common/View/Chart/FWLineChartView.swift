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
        pinchZoomEnabled = false
        scaleXEnabled = false
        scaleYEnabled = false

        dragYEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisEmptyFormatter

        leftAxis.labelCount = 3
        leftAxis.spaceTop = 0
        leftAxis.yOffset = 4
        leftAxis.forceLabelsEnabled = true
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
    func setChartData(_ data: ChartData, animated: Bool) {
        let chartValues = data.amounts.map(\.value)
        let dataEntries: [ChartDataEntry] = {
            if chartValues.count == 1 {
                return [
                    ChartDataEntry(x: Double(0), y: chartValues[0]),
                    ChartDataEntry(x: Double(1), y: chartValues[0])
                ]
            } else {
                return chartValues.enumerated().map { index, value in
                    ChartDataEntry(x: Double(index), y: value)
                }
            }
        }()

        if chartValues.contains(where: { $0 < Double.leastNonzeroMagnitude }) {
            leftAxis.axisMinimum = 0.0
        } else {
            leftAxis.resetCustomAxisMin()
        }

        let dataSet = LineChartDataSet(entries: dataEntries)
        dataSet.mode = .horizontalBezier
        dataSet.drawIconsEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawCirclesEnabled = false
        dataSet.colors = [R.color.colorAccent()!]
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
        dataSet.highlightColor = R.color.colorGreen()!
        dataSet.highlightLineWidth = 0.5
        dataSet.highlightLineDashLengths = [1, 3]
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        let lineChartData = LineChartData(dataSet: dataSet)

        xAxisLegend.setValues(data.xAxisValues)
        yAxisFormatter.bottomValueString = data.bottomYValue

        self.data = lineChartData
        if animated {
            animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
        }
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
