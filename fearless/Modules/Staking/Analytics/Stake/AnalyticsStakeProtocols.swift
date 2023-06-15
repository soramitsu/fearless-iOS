import SoraFoundation
import SSFModels

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
    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    )
}

protocol AnalyticsStakeViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubqueryStakeChangeData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?,
        hasPendingRewards: Bool
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
