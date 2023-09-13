import Foundation
import CommonWallet
import SoraFoundation
import SSFModels

final class WalletTransactionHistoryPresenter {
    weak var view: WalletTransactionHistoryViewProtocol?
    private let wireframe: WalletTransactionHistoryWireframeProtocol
    private let interactor: WalletTransactionHistoryInteractorInputProtocol
    private let viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol
    private var chainAsset: ChainAsset
    private let logger: LoggerProtocol

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
    func setup() {
        interactor.setup()
    }

    func loadNext() -> Bool {
        interactor.loadNext()
    }

    func didTapFiltersButton() {
        guard let filters = filters else {
            return
        }

        wireframe.presentFilters(with: filters, from: view, moduleOutput: self)
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
    func didReceive(filters: [FilterSet]) {
        self.filters = filters
    }

    func didReceive(
        pageData: AssetTransactionPageData,
        reload: Bool
    ) {
        view?.didStopLoading()
        guard chainAsset.chain.externalApi?.history != nil else {
            let state: WalletTransactionHistoryViewState = .unsupported
            view?.didReceive(state: state)
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
                filtersEnabled: chainAsset.chain.externalApi?.history?.type != .etherscan && chainAsset.chain.externalApi?.history != nil
            )

            let state: WalletTransactionHistoryViewState = reload
                ? .reloaded(viewModel: viewModel)
                : .loaded(viewModel: viewModel)
            view?.didReceive(state: state)
        } catch {
            logger.error("\(error)")
            view?.didReceive(state: .unsupported)
        }
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
