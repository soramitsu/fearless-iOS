import Foundation
import CommonWallet
import SoraFoundation

final class WalletTransactionHistoryPresenter {
    weak var view: WalletTransactionHistoryViewProtocol?
    private let wireframe: WalletTransactionHistoryWireframeProtocol
    private let interactor: WalletTransactionHistoryInteractorInputProtocol
    private let viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol
    private let chain: ChainModel
    private let asset: AssetModel
    private let logger: LoggerProtocol

    private var filters: [FilterSet]?
    private(set) var viewModels: [WalletTransactionHistorySection] = []

    init(
        interactor: WalletTransactionHistoryInteractorInputProtocol,
        wireframe: WalletTransactionHistoryWireframeProtocol,
        viewModelFactory: WalletTransactionHistoryViewModelFactoryProtocol,
        chain: ChainModel,
        asset: AssetModel,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension WalletTransactionHistoryPresenter: WalletTransactionHistoryModuleInput {
    func updateTransactionHistory() {
        interactor.reload()
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
            chain: chain,
            asset: asset,
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
        guard chain.externalApi?.history != nil else {
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
                lastChanges: viewChanges
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
        interactor.applyFilters(filters)
    }
}
