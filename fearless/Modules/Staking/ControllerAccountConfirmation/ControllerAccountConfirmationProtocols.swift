import SoraFoundation

protocol ControllerAccountConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol ControllerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func confirm()
}

protocol ControllerAccountConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
}

protocol ControllerAccountConfirmationInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didConfirmed(result: Result<String, Error>)
}

protocol ControllerAccountConfirmationWireframeProtocol: AddressOptionsPresentable,
    ErrorPresentable,
    AlertPresentable,
    StakingErrorPresentable {
    func complete(from view: ControllerAccountConfirmationViewProtocol?)
}
