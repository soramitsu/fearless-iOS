import SoraFoundation

protocol AnalyticsViewProtocol: ControllerBackedProtocol {
    func didReceiveChartData(_ data: ChartData)
}

protocol AnalyticsPresenterProtocol: AnyObject {
    func setup()
    func didSelectPeriod(_ period: AnalyticsPeriod)
}

protocol AnalyticsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsInteractorOutputProtocol: AnyObject {
    func didReceieve(rewardItemData: Result<[SubscanRewardItemData], Error>)
}

protocol AnalyticsWireframeProtocol: AnyObject {}
