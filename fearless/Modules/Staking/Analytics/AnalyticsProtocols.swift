import SoraFoundation

protocol AnalyticsViewProtocol: ControllerBackedProtocol {
    var stakeView: AnalyticsStakeViewProtocol? { get }
    func configureRewards(viewModel: LocalizableResource<AnalyticsRewardsViewModel>)
}

protocol AnalyticsPresenterProtocol: AnyObject {
    func setup()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectPrevious()
    func didSelectNext()
}

protocol AnalyticsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsInteractorOutputProtocol: AnyObject {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData], Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol AnalyticsWireframeProtocol: AnyObject {}
