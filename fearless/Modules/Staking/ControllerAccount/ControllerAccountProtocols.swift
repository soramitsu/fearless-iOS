import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol {}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountWireframeProtocol: AnyObject {}
