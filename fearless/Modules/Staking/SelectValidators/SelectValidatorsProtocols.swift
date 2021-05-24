import SoraFoundation

protocol SelectValidatorsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol SelectValidatorsPresenterProtocol: AnyObject {
    func setup()
}

protocol SelectValidatorsInteractorInputProtocol: AnyObject {}

protocol SelectValidatorsInteractorOutputProtocol: AnyObject {}

protocol SelectValidatorsWireframeProtocol: AnyObject {}
