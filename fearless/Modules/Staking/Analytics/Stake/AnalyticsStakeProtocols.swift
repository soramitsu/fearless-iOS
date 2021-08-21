import SoraFoundation

protocol AnalyticsStakeViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>)
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
    func fetchStakeHistory(stashAddress: AccountAddress)
}

protocol AnalyticsStakeInteractorOutputProtocol: AnyObject {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol AnalyticsStakeWireframeProtocol: AnyObject {
    func showRewardDetails(from view: ControllerBackedProtocol?)
}

protocol AnalyticsStakeViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubqueryStakeChangeData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        periodDelta: Int
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
