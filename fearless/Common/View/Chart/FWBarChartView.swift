import UIKit
import Charts

final class FWBarChartView: BarChartView {
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    weak var chartDelegate: FWChartViewDelegate?

    let xAxisEmptyFormatter = FWXAxisEmptyValueFormatter()
    let xAxisLegend = FWXAxisChartLegendView()

    let yAxisFormatter = FWYAxisChartFormatter()

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        maxVisibleCount = 40
        drawBarShadowEnabled = false
        drawValueAboveBarEnabled = false
        highlightFullBarEnabled = false

        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisEmptyFormatter

        leftAxis.labelCount = 2
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.valueFormatter = yAxisFormatter
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)
        leftAxis.axisMinimum = 0

        rightAxis.enabled = false
        drawBordersEnabled = false
        minOffset = 0
        legend.enabled = false

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

extension FWBarChartView: FWChartViewProtocol {
    func setChartData(_ data: ChartData) {
        let dataEntries = data.amounts.enumerated().map { index, amount in
            BarChartDataEntry(x: Double(index), yValues: [amount.value])
        }

        let set = BarChartDataSet(entries: dataEntries)
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.colors = data.amounts.map { chartData in
            chartData.filled ? R.color.colorAccent()! : R.color.colorGray()!
        }

        // xAxisEmptyFormatter.xAxisValues = data.xAxisValues
        xAxisLegend.setValues(data.xAxisValues)
        xAxis.labelCount = data.xAxisValues.count
        yAxisFormatter.bottomValueString = data.bottomYValue

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.4

        self.data = data
        animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
    }
}

extension FWBarChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        chartDelegate?.didSelectXValue(entry.x)
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        chartDelegate?.didUnselect()
    }
}
