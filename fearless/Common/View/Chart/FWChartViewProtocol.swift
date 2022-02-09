import UIKit

protocol FWChartViewDelegate: AnyObject {
    func didSelectXValue(_ value: Double)
    func didUnselect()
}

protocol FWChartViewProtocol where Self: UIView {
    func setChartData(_ data: ChartData, animated: Bool)
    var chartDelegate: FWChartViewDelegate? { get set }
}

extension FWChartViewProtocol {
    func setChartData(_ data: ChartData, animated: Bool = true) {
        setChartData(data, animated: animated)
    }
}
