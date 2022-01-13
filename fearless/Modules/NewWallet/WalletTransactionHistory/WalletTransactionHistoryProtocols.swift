import CommonWallet
protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func loadNext() -> Bool
}

protocol WalletTransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
    func loadNext() -> Bool
}

protocol WalletTransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    )
}

protocol WalletTransactionHistoryWireframeProtocol: AnyObject {}
