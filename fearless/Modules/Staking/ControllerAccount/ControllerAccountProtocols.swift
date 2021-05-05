import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>)
}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountWireframeProtocol: AnyObject {}
