import CommonWallet
protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup()
}

protocol WalletTransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletTransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(
        pageData: AssetTransactionPageData,
        andSwitch newDataLoadingState: WalletTransactionHistoryDataState,
        reload: Bool
    )
}

protocol WalletTransactionHistoryWireframeProtocol: AnyObject {}
