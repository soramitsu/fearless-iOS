import RobinHood
import SSFModels
import UIKit
import XCTest
@testable import fearless

// Doubles for the WalletTransactionHistory lane-H tests.

final class CovHTxHistoryInputSpy: WalletTransactionHistoryInteractorInputProtocol {
    weak var output: WalletTransactionHistoryInteractorOutputProtocol?
    var url = URL(string: "https://explorer.invalid/address/wallet")
    var nextResult = true
    private(set) var reloads = 0
    private(set) var changedAssets: [ChainAsset] = []
    private(set) var appliedFilters: [[FilterSet]] = []

    func setup(with presenter: WalletTransactionHistoryInteractorOutputProtocol?) { output = presenter }
    func loadNext() -> Bool { nextResult }
    func applyFilters(_ filters: [FilterSet]) { appliedFilters.append(filters) }
    func reload() { reloads += 1 }
    func chainAssetChanged(_ newChainAsset: ChainAsset) { changedAssets.append(newChainAsset) }
    func historyExplorerURL() -> URL? { url }
}

final class CovHTxHistoryWireframeSpy: WalletTransactionHistoryWireframeProtocol {
    private(set) var filters: [[FilterSet]] = []
    private(set) var details: [AssetTransactionData] = []
    private(set) var explorers: [URL] = []

    func presentFilters(with filters: [FilterSet], from _: ControllerBackedProtocol?, mode _: FiltersMode, moduleOutput _: FiltersModuleOutput?) {
        self.filters.append(filters)
    }

    func showHistoryExplorer(url: URL, from _: ControllerBackedProtocol) { explorers.append(url) }

    func showTransactionDetails(
        from _: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {
        details.append(transaction)
    }
}

final class CovHTxHistoryViewSpy: UIViewController, WalletTransactionHistoryViewProtocol {
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var states: [WalletTransactionHistoryViewState] = []
    private(set) var failures: [Bool] = []
    var delegate: DraggableDelegate?
    var draggableView: UIView { view }
    var scrollPanRecognizer: UIPanGestureRecognizer? { nil }

    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
    func didReceive(state: WalletTransactionHistoryViewState) { states.append(state) }
    func reloadContent() {}
    func didReceiveHistoryFailure(canViewExplorer: Bool) { failures.append(canViewExplorer) }
    func set(dragableState _: DraggableState, animated _: Bool) {}
    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool { false }
    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}
}

final class CovHTxHistoryPresenterSpy: WalletTransactionHistoryPresenterProtocol {
    weak var view: WalletTransactionHistoryViewProtocol?
    var nextResult = false
    private(set) var loadNextCalls = 0
    private(set) var retries = 0
    private(set) var explorerTaps = 0
    private(set) var filterTaps = 0
    private(set) var selected: [WalletTransactionHistoryCellViewModel] = []

    func setup(with view: WalletTransactionHistoryViewProtocol) { self.view = view }
    func loadNext() -> Bool {
        loadNextCalls += 1
        return nextResult
    }

    func retryHistory() { retries += 1 }
    func viewHistoryOnExplorer() { explorerTaps += 1 }
    func didSelect(viewModel: WalletTransactionHistoryCellViewModel) { selected.append(viewModel) }
    func didTapFiltersButton() { filterTaps += 1 }
}

final class CovHTxHistoryDraggableDelegate: DraggableDelegate {
    let navigationItem = UINavigationItem(title: "Before")
    private(set) var transits: [DraggableState] = []

    var presentationNavigationItem: UINavigationItem? { navigationItem }

    func wantsTransit(to draggableState: DraggableState, animating _: Bool) { transits.append(draggableState) }
}

final class CovHTxHistoryRemote: HistoryServiceProtocol {
    struct Call {
        let address: String
        let pagination: Pagination
        let completion: TransactionHistoryBlock
    }

    private(set) var calls: [Call] = []

    func fetchTransactionHistory(
        for address: String,
        asset _: AssetModel,
        chain _: ChainModel,
        filters _: [WalletTransactionHistoryFilter],
        pagination: Pagination,
        runCompletionIn _: DispatchQueue,
        completionBlock: @escaping TransactionHistoryBlock
    ) -> CancellableCall {
        calls.append(Call(address: address, pagination: pagination, completion: completionBlock))
        return CovHTxHistoryCancellable()
    }

    func complete(_ index: Int, _ result: Result<AssetTransactionPageData?, Error>?) {
        calls[index].completion(result)
    }
}

final class CovHTxHistoryCancellable: CancellableCall {
    func cancel() {}
}

final class CovHTxHistoryDependencies: WalletTransactionHistoryDependencyContaining {
    let remote: CovHTxHistoryRemote
    let provider: SingleValueProvider<AssetTransactionPageData>?
    var dependencies: WalletTransactionHistoryDependencyContainer.WalletTransactionHistoryDependencies?

    init(remote: CovHTxHistoryRemote, provider: SingleValueProvider<AssetTransactionPageData>? = nil) {
        self.remote = remote
        self.provider = provider
    }

    func createDependencies(for _: ChainAsset, selectedAccount _: MetaAccountModel) throws {
        dependencies = .init(dataProvider: provider, historyService: remote)
    }
}

final class CovHTxHistoryOutputSpy: WalletTransactionHistoryInteractorOutputProtocol {
    private(set) var pages: [(page: AssetTransactionPageData, reload: Bool)] = []
    private(set) var failures: [Bool] = []
    private(set) var unsupported = 0
    private(set) var resets = 0
    private(set) var filters: [[FilterSet]] = []

    var pageIds: [[String]] { pages.map { $0.page.transactions.map(\.transactionId) } }

    func didReceive(pageData: AssetTransactionPageData, reload: Bool) { pages.append((pageData, reload)) }
    func didReceive(filters: [FilterSet]) { self.filters.append(filters) }
    func didReceiveUnsupported() { unsupported += 1 }
    func didReceiveHistoryFailure(hasCachedHistory: Bool) { failures.append(hasCachedHistory) }
    func didResetHistory() { resets += 1 }
}

/// A single-value source that answers with the scripted page.
final class CovHTxHistoryPageSource: SingleValueProviderSourceProtocol {
    typealias Model = AssetTransactionPageData

    var page: AssetTransactionPageData?

    init(page: AssetTransactionPageData?) {
        self.page = page
    }

    func fetchOperation() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let page = page
        return CompoundOperationWrapper(targetOperation: ClosureOperation { page })
    }
}

final class CovHTxHistoryEmptyRepository: DataProviderRepositoryProtocol {
    typealias Model = SingleValueProviderObject

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {}
    }
}
