import SoraFoundation

protocol AnalyticsValidatorsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>)
    func updateChartCenterText(_ text: NSAttributedString)
}

protocol AnalyticsValidatorsPresenterProtocol: AnyObject {
    func setup()
    func reload()
    func handleValidatorInfoAction(validatorAddress: AccountAddress)
    func handlePageAction(page: AnalyticsValidatorsPage)
    func handleChartSelectedValidator(_ validator: AnalyticsValidatorItemViewModel)
    func handleChartSelectedInactiveSegment(_ inactiveSegment: AnalyticsValidatorsViewModel.InactiveSegment)
}

protocol AnalyticsValidatorsInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol AnalyticsValidatorsInteractorOutputProtocol: AnyObject {
    func didReceive(identitiesByAddressResult: Result<[AccountAddress: AccountIdentity], Error>)
    func didReceive(eraValidatorInfosResult: Result<[SubqueryEraValidatorInfo], Error>)
    func didReceive(stashAddressResult: Result<AccountAddress?, Error>)
    func didReceive(rewardsResult: Result<[SubqueryRewardItemData], Error>)
    func didReceive(nominationResult: Result<Nomination?, Error>)
}

protocol AnalyticsValidatorsWireframeProtocol: AnyObject {
    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?)
}

protocol AnalyticsValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        eraValidatorInfos: [SubqueryEraValidatorInfo],
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData],
        nomination: Nomination,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage,
        locale: Locale
    ) -> AnalyticsValidatorsViewModel

    func chartCenterText(validator: AnalyticsValidatorItemViewModel) -> NSAttributedString
    func chartCenterTextInactiveSegment(
        _ inactiveSegment: AnalyticsValidatorsViewModel.InactiveSegment
    ) -> NSAttributedString
}
