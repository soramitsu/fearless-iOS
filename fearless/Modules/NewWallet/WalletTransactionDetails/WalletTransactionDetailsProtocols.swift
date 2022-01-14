import CommonWallet
protocol WalletTransactionDetailsViewProtocol: ControllerBackedProtocol {
    func didReceiveState(_ state: WalletTransactionDetailsViewState)
}

protocol WalletTransactionDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletTransactionDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletTransactionDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveTransaction(_ transaction: AssetTransactionData)
}

protocol WalletTransactionDetailsWireframeProtocol: AnyObject {}
