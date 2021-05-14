import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: ControllerAccountViewModel)
}

protocol ControllerAccountViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        stashItem: StashItem,
        stashAccountItem: AccountItem?,
        chosenAccountItem: AccountItem?
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
    func estimateFee(for account: AccountItem)
    func fetchLedger(controllerAddress: AccountAddress)
}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStashAccount(result: Result<AccountItem?, Error>)
    func didReceiveControllerAccount(result: Result<AccountItem?, Error>)
    func didReceiveAccounts(result: Result<[AccountItem], Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
}

protocol ControllerAccountWireframeProtocol: WebPresentable,
    AddressOptionsPresentable,
    AccountSelectionPresentable,
    StakingErrorPresentable,
    AlertPresentable,
    ErrorPresentable {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: AccountItem
    )
    func close(view: ControllerBackedProtocol?)
}
