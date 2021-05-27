import UIKit
import Charts

final class ChartView: BarChartView {
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "$"
        return formatter
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        dragEnabled = false
        maxVisibleCount = 40
        drawBarShadowEnabled = false
        drawValueAboveBarEnabled = false
        highlightFullBarEnabled = false

        xAxis.gridLineDashLengths = [2.5, 2.5]
        xAxis.gridLineDashPhase = 0
        xAxis.gridColor = UIColor.white.withAlphaComponent(0.64)
        xAxis.labelFont = .p3Paragraph

        leftAxis.labelCount = 2
        leftAxis.valueFormatter = DefaultAxisValueFormatter(formatter: formatter)
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)
        leftAxis.axisMinimum = 0

        rightAxis.enabled = false

        xAxis.labelPosition = .bottom
        drawBordersEnabled = false

        legend.enabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
