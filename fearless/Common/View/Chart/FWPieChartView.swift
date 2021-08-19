import UIKit
import Charts

protocol FWPieChartViewProtocol: FWChartViewProtocol {
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWPieChartView: FWPieChartViewProtocol {
    func setChartData(_ data: ChartData) {
        let entries = data.amounts.map { PieChartDataEntry(value: $0) }

        let set = PieChartDataSet(entries: entries)
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 4

        set.colors = [R.color.colorAccent()!]

        let data = PieChartData(dataSet: set)
        self.data = data
    }

    func setCenterText(_ text: NSAttributedString) {
        centerAttributedText = text
    }
}
