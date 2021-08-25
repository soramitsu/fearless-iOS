import SoraFoundation

protocol AnalyticsRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol AnalyticsRewardDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol AnalyticsRewardDetailsInteractorInputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsWireframeProtocol: AnyObject {}
