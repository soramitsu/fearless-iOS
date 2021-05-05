import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>)
}

protocol ControllerAccountViewModelFactoryProtocol: AnyObject {
    func createViewModel(stashItem: StashItem?) -> LocalizableResource<ControllerAccountViewModel>
}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func selectLearnMore()
    func proceed()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol ControllerAccountWireframeProtocol: WebPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
}
