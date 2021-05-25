import SoraFoundation

protocol AnalyticsViewProtocol: ControllerBackedProtocol {}

protocol AnalyticsPresenterProtocol: AnyObject {
    func setup()
}

protocol AnalyticsInteractorInputProtocol: AnyObject {}

protocol AnalyticsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsWireframeProtocol: AnyObject {}
