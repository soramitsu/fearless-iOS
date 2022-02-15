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
}

protocol WalletDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(chainsWithAccounts: [ChainModel: ChainAccountResponse])
    func didReceive(error: Error)
}

protocol WalletDetailsWireframeProtocol: ErrorPresentable,
    AlertPresentable,
    AddressOptionsPresentable,
    AuthorizationPresentable {
    func close(_ view: WalletDetailsViewProtocol)
    func showExport(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    )
}
