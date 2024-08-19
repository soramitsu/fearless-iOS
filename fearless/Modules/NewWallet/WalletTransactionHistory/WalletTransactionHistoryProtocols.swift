
import SSFModels

protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable, LoadableViewProtocol {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup(with view: WalletTransactionHistoryViewProtocol)
    func loadNext() -> Bool
    func didSelect(viewModel: WalletTransactionHistoryCellViewModel)
    func didTapFiltersButton()
    func didChangeFiltersSliderValue(index: Int)
}

protocol WalletTransactionHistoryInteractorInputProtocol: AnyObject {
    func setup(with presenter: WalletTransactionHistoryInteractorOutputProtocol?)
    func loadNext() -> Bool
    func applyFilters(_ filters: [FilterSet])
    func reload()
    func chainAssetChanged(_ newChainAsset: ChainAsset)
}

protocol WalletTransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    )

    func didReceive(filters: [FilterSet])
    func didReceiveUnsupported()
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

protocol WalletTransactionHistoryModuleInput: AnyObject {
    func updateTransactionHistory(for chainAsset: ChainAsset?)
}
