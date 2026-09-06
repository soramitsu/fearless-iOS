import Foundation

import SoraFoundation
import SSFModels

final class WalletTransactionHistoryPresenter {
    weak var view: WalletTransactionHistoryViewProtocol?
    private let wireframe: WalletTransactionHistoryWireframeProtocol
    private let interactor: WalletTransactionHistoryInteractorInputProtocol
    private let viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol
    private var chainAsset: ChainAsset
    private let logger: LoggerProtocol

    private var historyRecoveryNeeded = false
    private var filters: [FilterSet]?
    private(set) var viewModels: [WalletTransactionHistorySection] = []

    init(
        interactor: WalletTransactionHistoryInteractorInputProtocol,
        wireframe: WalletTransactionHistoryWireframeProtocol,
        viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryModuleInput {
    func updateTransactionHistory(for chainAsset: ChainAsset?) {
        if let chainAsset = chainAsset {
            self.chainAsset = chainAsset
            interactor.chainAssetChanged(chainAsset)
        } else {
            interactor.reload()
        }
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryPresenterProtocol {
    func didChangeFiltersSliderValue(index: Int) {
        guard let type = WalletTransactionHistoryFilter.HistoryFilterType.type(from: index) else {
            return
        }

        let filter = WalletTransactionHistoryFilter(type: type, selected: true)
        let filters = [FilterSet(title: nil, items: [filter])]
        interactor.applyFilters(filters)
    }

    func setup(with view: WalletTransactionHistoryViewProtocol) {
        self.view = view
        interactor.setup(with: self)
    }

    func loadNext() -> Bool {
        historyRecoveryNeeded ? false : interactor.loadNext()
    }

    func retryHistory() {
        view?.didStartLoading()
        interactor.reload()
    }

    func viewHistoryOnExplorer() {
        guard let view, let url = interactor.historyExplorerURL() else { return }
        wireframe.showHistoryExplorer(url: url, from: view)
    }

    func didTapFiltersButton() {
        guard let filters = filters else {
            return
        }

        let mode: FiltersMode = chainAsset.chain.isReef ? .singleSelection : .multiSelection
        wireframe.presentFilters(with: filters, from: view, mode: mode, moduleOutput: self)
    }

    func didSelect(viewModel: WalletTransactionHistoryCellViewModel) {
        guard let selectedAccount = SelectedWalletSettings.shared.value else {
            return
        }
        wireframe.showTransactionDetails(
            from: view,
            transaction: viewModel.transaction,
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            selectedAccount: selectedAccount
        )
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryInteractorOutputProtocol {
    func didReceiveUnsupported() {
        didReceiveHistoryFailure()
    }

    func didReceiveHistoryFailure() {
        historyRecoveryNeeded = true
        view?.didStopLoading()
        view?.didReceiveHistoryFailure(canViewExplorer: interactor.historyExplorerURL() != nil)
    }

    func didResetHistory() {
        historyRecoveryNeeded = false
        viewModels = []
        view?.didReceive(state: .loading)
    }

    func didReceive(filters: [FilterSet]) {
        self.filters = filters
    }

    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    ) {
        historyRecoveryNeeded = false
        view?.didStopLoading()
        guard chainAsset.chain.externalApi?.history != nil else {
            didReceiveHistoryFailure()
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        var viewModels = reload ? [] : self.viewModels
        do {
            let viewChanges = try viewModelFactory.merge(
                newItems: pageData.transactions,
                into: &viewModels,
                locale: locale
            )

            self.viewModels = viewModels
            let viewModel = WalletTransactionHistoryViewModel(
                sections: viewModels,
                lastChanges: viewChanges,
                filtering: buildFiltering(for: chainAsset.chain)
            )

            let state: WalletTransactionHistoryViewState = reload
                ? .reloaded(viewModel: viewModel)
                : .loaded(viewModel: viewModel)
            view?.didReceive(state: state)
        } catch {
            logger.error("History could not be displayed")
            didReceiveHistoryFailure()
        }
    }

    private func buildFiltering(for chain: ChainModel) -> WalletTransactionHistoryViewFilterMode {
        if chain.isReef {
            return .single
        }
        guard let explorerType = chain.externalApi?.history?.type, explorerType.hasFilters else {
            return .disabled
        }

        let supportsMultiple = explorerType != .etherscan && chain.externalApi?.history != nil
        return supportsMultiple ? .multiple : .disabled
    }
}

extension WalletTransactionHistoryPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletTransactionHistoryPresenter: FiltersModuleOutput {
    func didFinishWithFilters(filters: [FilterSet]) {
        view?.didStartLoading()
        interactor.applyFilters(filters)
    }
}
