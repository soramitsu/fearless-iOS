import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: ControllerAccountViewModel)
}

protocol ControllerAccountViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        stashItem: StashItem,
        chosenAccountItem: AccountItem,
        accounts: [AccountItem]
    ) -> ControllerAccountViewModel
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
    func estimateFee(controllerAddress: AccountAddress)
}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveAccounts(result: Result<[AccountItem], Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol ControllerAccountWireframeProtocol: WebPresentable,
    AddressOptionsPresentable,
    AccountSelectionPresentable,
    StakingErrorPresentable,
    AlertPresentable,
    ErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
    func close(view: ControllerBackedProtocol?)
}
