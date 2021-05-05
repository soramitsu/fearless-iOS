import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountWireframeProtocol: AnyObject {}
