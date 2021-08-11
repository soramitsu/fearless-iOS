import SoraFoundation

protocol AnalyticsValidatorsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>)
}

protocol AnalyticsValidatorsPresenterProtocol: AnyObject {
    func setup()
    func handleValidatorInfoAction(validatorAddress: AccountAddress)
    func handlePageAction(page: AnalyticsValidatorsPage)
}

protocol AnalyticsValidatorsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsValidatorsInteractorOutputProtocol: AnyObject {
    func didReceive(identitiesByAddressResult: Result<[AccountAddress: AccountIdentity], Error>)
}

protocol AnalyticsValidatorsWireframeProtocol: AnyObject {
    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?)
}

protocol AnalyticsValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel>
}
