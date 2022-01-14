import CommonWallet
protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func loadNext() -> Bool
    func didSelect(viewModel: WalletTransactionHistoryCellViewModel)
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

protocol WalletTransactionHistoryWireframeProtocol: AnyObject {
    func showTransactionDetails(
        from view: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )
}
