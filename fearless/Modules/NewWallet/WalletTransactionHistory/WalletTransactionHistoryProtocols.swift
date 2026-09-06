
import Foundation
import SSFModels

protocol WalletTransactionHistoryViewProtocol: ControllerBackedProtocol, Draggable, LoadableViewProtocol {
    func didReceive(state: WalletTransactionHistoryViewState)
    func reloadContent()
    func didReceiveHistoryFailure(canViewExplorer: Bool)
}

protocol WalletTransactionHistoryPresenterProtocol: AnyObject {
    func setup(with view: WalletTransactionHistoryViewProtocol)
    func loadNext() -> Bool
    func retryHistory()
    func viewHistoryOnExplorer()
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
    func historyExplorerURL() -> URL?
}

protocol WalletTransactionHistoryInteractorOutputProtocol: AnyObject {
    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    )

    func didReceive(filters: [FilterSet])
    func didReceiveUnsupported()
    func didReceiveHistoryFailure()
    func didResetHistory()
}

protocol WalletTransactionHistoryWireframeProtocol: AnyObject, FiltersPresentable {
    func showHistoryExplorer(url: URL, from view: ControllerBackedProtocol)
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
