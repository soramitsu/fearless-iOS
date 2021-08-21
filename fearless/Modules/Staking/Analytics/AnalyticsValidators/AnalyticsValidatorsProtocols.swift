import SoraFoundation

protocol AnalyticsValidatorsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>)
}

protocol AnalyticsValidatorsPresenterProtocol: AnyObject {
    func setup()
    func reload()
    func handleValidatorInfoAction(validatorAddress: AccountAddress)
    func handlePageAction(page: AnalyticsValidatorsPage)
}

protocol AnalyticsValidatorsInteractorInputProtocol: AnyObject {
    func setup()
    func fetchRewards(stashAddress: AccountAddress)
}

protocol AnalyticsValidatorsInteractorOutputProtocol: AnyObject {
    func didReceive(identitiesByAddressResult: Result<[AccountAddress: AccountIdentity], Error>)
    func didReceive(eraValidatorInfosResult: Result<[SQEraValidatorInfo], Error>)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
    func didReceive(rewardsResult: Result<[SubqueryRewardItemData], Error>)
    func didReceive(nominationResult: Result<Nomination?, Error>)
}

protocol AnalyticsValidatorsWireframeProtocol: AnyObject {
    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?)
}

protocol AnalyticsValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        eraValidatorInfos: [SQEraValidatorInfo],
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData],
        nomination: Nomination,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel>
}
