import SoraFoundation

protocol AnalyticsStakeViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>)
}

protocol AnalyticsStakePresenterProtocol: AnalyticsPresenterBaseProtocol {}

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
    func showRewardDetails(_ rewardModel: AnalyticsRewardDetailsModel, from view: ControllerBackedProtocol?)
}

protocol AnalyticsStakeViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubqueryStakeChangeData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
