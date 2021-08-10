import SoraFoundation

protocol AnalyticsValidatorsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>)
}

protocol AnalyticsValidatorsPresenterProtocol: AnyObject {
    func setup()
    func handleValidatorInfoAction(validatorAddress: AccountAddress)
}

protocol AnalyticsValidatorsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsValidatorsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsValidatorsWireframeProtocol: AnyObject {
    func showValidatorInfo(address: AccountAddress, view: ControllerBackedProtocol?)
}

protocol AnalyticsValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel() -> LocalizableResource<AnalyticsValidatorsViewModel>
}
