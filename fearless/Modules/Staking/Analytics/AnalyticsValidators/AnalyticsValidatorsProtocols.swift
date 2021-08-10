import SoraFoundation

protocol AnalyticsValidatorsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>)
}

protocol AnalyticsValidatorsPresenterProtocol: AnyObject {
    func setup()
}

protocol AnalyticsValidatorsInteractorInputProtocol: AnyObject {}

protocol AnalyticsValidatorsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsValidatorsWireframeProtocol: AnyObject {}

protocol AnalyticsValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel() -> LocalizableResource<AnalyticsValidatorsViewModel>
}
