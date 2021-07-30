import SoraFoundation

protocol AnalyticsRewardsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>)
}

protocol AnalyticsRewardsPresenterProtocol: AnyObject {
    func setup()
    func reload()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectPrevious()
    func didSelectNext()
    func handleReward(atIndex index: Int)
}

protocol AnalyticsRewardsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsRewardsInteractorOutputProtocol: AnyObject {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData], Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol AnalyticsRewardsWireframeProtocol: AnyObject {
    func showRewardDetails(from view: ControllerBackedProtocol?)
}

protocol AnalyticsRewardsViewModelFactoryProtocol {
    func createRewardsViewModel(
        from data: [SubqueryRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        periodDelta: Int
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
