import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>)
}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func selectLearnMore()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountWireframeProtocol: WebPresentable {}
