import SoraFoundation
import CommonWallet

protocol StakingBondMoreViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
}

protocol StakingBondMorePresenterProtocol: AnyObject {
    func setup()
    func handleContinueAction()
    func updateAmount(_ newValue: Decimal)
}

protocol StakingBondMoreInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {}

protocol StakingBondMoreWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
}
