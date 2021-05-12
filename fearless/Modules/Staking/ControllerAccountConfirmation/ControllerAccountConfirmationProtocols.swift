import SoraFoundation

protocol ControllerAccountConfirmationViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol ControllerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountConfirmationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountConfirmationInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol ControllerAccountConfirmationWireframeProtocol: AnyObject {}
