import SoraFoundation

protocol WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol)
    func updateData()
    func didTapCloseButton()
    func willDisappear()
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

protocol WalletDetailsWireframeProtocol: ErrorPresentable, AlertPresentable {
    func close(_ view: WalletDetailsViewProtocol)
}
