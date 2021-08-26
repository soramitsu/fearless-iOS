import SoraFoundation

protocol AnalyticsRewardsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>)
}

protocol AnalyticsRewardsPresenterProtocol: AnalyticsPresenterBaseProtocol {
    func handlePendingRewardsAction()
}

protocol AnalyticsRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func fetchRewards(stashAddress: AccountAddress)
}

protocol AnalyticsRewardsInteractorOutputProtocol: AnyObject {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData]?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol AnalyticsRewardsWireframeProtocol: AnyObject {
    func showRewardDetails(_ rewardModel: AnalyticsRewardDetailsModel, from view: ControllerBackedProtocol?)
    func showPendingRewards(from view: ControllerBackedProtocol?, stashAddress: AccountAddress)
}

protocol AnalyticsRewardsViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubqueryRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
