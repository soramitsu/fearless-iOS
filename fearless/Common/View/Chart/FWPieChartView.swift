import UIKit
import Charts

final class FWPieChartView: PieChartView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        drawEntryLabelsEnabled = false
        holeRadiusPercent = 0.8
        holeColor = .clear
        legend.enabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FWPieChartView: FWChartViewProtocol {
    func setChartData(_ data: ChartData) {
        let entries = (0 ..< data.amounts.count).map { (_) -> PieChartDataEntry in
            // IMPORTANT: In a PieChart, no values (Entry) should have the same xIndex (even if from different DataSets), since no values can be drawn above each other.
            PieChartDataEntry(value: Double(arc4random_uniform(10)))
        }

        let set = PieChartDataSet(entries: entries)
        set.drawIconsEnabled = false
        set.sliceSpace = 8

        set.colors = [R.color.colorAccent()!]

        let data = PieChartData(dataSet: set)
        self.data = data
    }
}
