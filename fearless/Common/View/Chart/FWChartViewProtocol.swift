import UIKit

protocol FWChartViewDelegate: AnyObject {
    func didSelectXValue(_ value: Double)
    func didUnselect()
}

protocol FWChartViewProtocol where Self: UIView {
    func setChartData(_ data: ChartData)
    var chartDelegate: FWChartViewDelegate? { get set }
}
