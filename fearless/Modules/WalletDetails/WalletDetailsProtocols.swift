import SoraFoundation

protocol WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol)
    func updateData()
    func didTapCloseButton()
    func willDisappear()
    func showActions(for chain: ChainModel)
}

protocol WalletDetailsViewProtocol: ControllerBackedProtocol {
    func setInput(viewModel: InputViewModelProtocol)
    func bind(to viewModel: WalletDetailsViewModel)
}

protocol WalletDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func update(walletName: String)
    func getAvailableExportOptions(for chain: ChainModel, address: String)
}

protocol WalletDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(chainsWithAccounts: [ChainModel: ChainAccountResponse])
    func didReceiveExportOptions(options: [ExportOption], for chain: ChainModel)
    func didReceive(error: Error)
}

protocol WalletDetailsWireframeProtocol: ErrorPresentable,
    AlertPresentable,
    ModalAlertPresenting,
    AuthorizationPresentable {
    func close(_ view: WalletDetailsViewProtocol)
    func presentAcions(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        callback: @escaping ModalPickerSelectionCallback
    )
    func showExport(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    )
    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    )
    func present(
        from view: ControllerBackedProtocol,
        url: URL
    )
}
