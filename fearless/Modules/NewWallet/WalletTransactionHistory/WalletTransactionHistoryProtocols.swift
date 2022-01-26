import CommonWallet
protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup()
    func loadNext() -> Bool
    func didSelect(viewModel: WalletTransactionHistoryCellViewModel)
    func didTapFiltersButton()
}

protocol WalletTransactionHistoryInteractorInputProtocol: AnyObject {
    func setup()
    func loadNext() -> Bool
    func applyFilters(_ filters: [WalletTransactionHistoryFilter])
}

protocol WalletTransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    )

    func didReceive(filters: [WalletTransactionHistoryFilter])
}

protocol WalletTransactionHistoryWireframeProtocol: AnyObject, FiltersPresentable {
    func showTransactionDetails(
        from view: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )
}
