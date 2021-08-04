import SoraFoundation

protocol AnalyticsStakeViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsStakeViewModel>)
}

protocol AnalyticsStakePresenterProtocol: AnyObject {
    func setup()
    func reload()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectPrevious()
    func didSelectNext()
    func handleReward(atIndex index: Int)
}

protocol AnalyticsStakeInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsStakeInteractorOutputProtocol: AnyObject {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol AnalyticsStakeWireframeProtocol: AnyObject {
    func showRewardDetails(from view: ControllerBackedProtocol?)
}
