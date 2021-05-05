import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>)
    func enableActionButton(_ enable: Bool)
}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func selectLearnMore()
    func proceed()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountWireframeProtocol: WebPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
}
