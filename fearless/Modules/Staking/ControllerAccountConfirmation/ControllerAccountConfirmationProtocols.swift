import SoraFoundation

protocol ControllerAccountConfirmationViewProtocol: ControllerBackedProtocol, Localizable {}

protocol ControllerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountConfirmationInteractorInputProtocol: AnyObject {}

protocol ControllerAccountConfirmationInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountConfirmationWireframeProtocol: AnyObject {}
