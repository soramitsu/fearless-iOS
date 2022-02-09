protocol WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol)
    func updateData()
    func didTapCloseButton()
}

protocol WalletDetailsViewProtocol: ControllerBackedProtocol {
    func bind(to viewModel: WalletDetailsViewModel)
}

protocol WalletDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(chainsWithAccounts: [ChainModel: ChainAccountResponse])
}

protocol WalletDetailsWireframeProtocol: AnyObject {
    func close(_ view: WalletDetailsViewProtocol)
}
