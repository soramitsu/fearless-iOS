import SoraFoundation

protocol StakingBondMoreViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<String>)
}

protocol StakingBondMoreViewModelFactoryProtocol {
    func createViewModel(from data: String) -> LocalizableResource<String>
}

protocol StakingBondMorePresenterProtocol: AnyObject {
    func setup()
    func handleContinueAction()
}

protocol StakingBondMoreInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {}

protocol StakingBondMoreWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
}
