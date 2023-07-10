import UIKit
import CommonWallet
import RobinHood
import SoraFoundation
import SSFModels

final class WalletTransactionHistoryInteractor {
    private enum Constants {
        static let reloadInterval: TimeInterval = 30.0
    }

    weak var presenter: WalletTransactionHistoryInteractorOutputProtocol?
    private let dependencyContainer: WalletTransactionHistoryDependencyContainer
    let logger: LoggerProtocol?
    var defaultFilter: WalletHistoryRequest
    var chainAsset: ChainAsset
    let selectedAccount: MetaAccountModel
    private(set) var selectedFilter: WalletHistoryRequest
    var filters: [FilterSet]
    let transactionsPerPage: Int
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandler

    private(set) var dataLoadingState: WalletTransactionHistoryDataState = .waitingCached
    private(set) var pages: [AssetTransactionPageData] = []

    private var reloadTimer: Timer?

    init(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        dependencyContainer: WalletTransactionHistoryDependencyContainer,
        logger: LoggerProtocol?,
        defaultFilter: WalletHistoryRequest,
        selectedFilter: WalletHistoryRequest,
        transactionsPerPage: Int = 100,
        filters: [FilterSet],
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandler
    ) {
        self.selectedAccount = selectedAccount
        self.dependencyContainer = dependencyContainer
        self.logger = logger
        self.selectedFilter = selectedFilter
        self.defaultFilter = defaultFilter
        self.transactionsPerPage = transactionsPerPage
        self.filters = filters
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        chainAsset = ChainAsset(chain: chain, asset: asset)

        applicationHandler.delegate = self
    }

    private func loadTransactions(for pagination: Pagination) {
        guard let utilityChainAsset = getUtilityAsset(for: chainAsset) else {
            return
        }

        guard let address = selectedAccount.fetch(for: utilityChainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let filterValues: [WalletTransactionHistoryFilter] = filters.compactMap {
            $0.items as? [WalletTransactionHistoryFilter]
        }.reduce([], +)

        dependencyContainer.dependencies?.historyService.fetchTransactionHistory(
            for: address,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            filters: filterValues,
            pagination: pagination,
            runCompletionIn: .main
        ) { [weak self] optionalResult in
            if let result = optionalResult {
                switch result {
                case let .success(pageData):
                    let loadedData = pageData ??
                        AssetTransactionPageData(transactions: [])
                    self?.handleNext(
                        transactionData: loadedData,
                        for: pagination
                    )
                case let .failure(error):
                    self?.handleNext(error: error, for: pagination)
                }
            }
        }
    }

    private func handleDataProvider(transactionData: AssetTransactionPageData?) {
        switch dataLoadingState {
        case .waitingCached:
            let loadedTransactionData = transactionData ?? AssetTransactionPageData(transactions: [])

            dataLoadingState = WalletTransactionHistoryDataState.loading(
                page: Pagination(count: transactionsPerPage),
                previousPage: nil
            )

            presenter?.didReceive(
                pageData: loadedTransactionData,
                reload: true
            )

            pages = [loadedTransactionData]

            dependencyContainer.dependencies?.dataProvider?.refresh()

        case .loading, .loaded:
            if let transactionData = transactionData {
                let loadedPage = Pagination(count: transactionData.transactions.count)
                dataLoadingState = WalletTransactionHistoryDataState.loaded(
                    page: loadedPage,
                    nextContext: transactionData.context
                )

                presenter?.didReceive(
                    pageData: transactionData,
                    reload: true
                )

                pages = [transactionData]

            } else if let firstPage = pages.first {
                let loadedPage = Pagination(count: firstPage.transactions.count)
                dataLoadingState = WalletTransactionHistoryDataState.loaded(
                    page: loadedPage,
                    nextContext: firstPage.context
                )
                presenter?.didReceive(
                    pageData: firstPage,
                    reload: true
                )

            } else {
                logger?.error("Inconsistent data loading before cache")
            }

        default: break
        }
    }

    private func handleDataProvider(error: Error) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cache unexpectedly failed \(error)")
        case .loading:
            if let firstPage = pages.first {
                let loadedPage = Pagination(count: firstPage.transactions.count, context: nil)
                dataLoadingState = .loaded(page: loadedPage, nextContext: firstPage.context)
                presenter?.didReceive(
                    pageData: firstPage,
                    reload: true
                )
            }

            logger?.debug("Cache refresh failed \(error)")
        case .loaded:
            logger?.debug("Unexpected loading failed \(error)")
        default: break
        }
    }

    private func handleNext(transactionData: AssetTransactionPageData, for pagination: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Unexpected page loading before cache")
        case let .loading(currentPagination, _):
            if currentPagination == pagination {
                let loadedPage = Pagination(count: transactionData.transactions.count, context: pagination.context)
                dataLoadingState = WalletTransactionHistoryDataState.loaded(
                    page: loadedPage,
                    nextContext: transactionData.context
                )
                presenter?.didReceive(
                    pageData: transactionData,
                    reload: false
                )

                pages.append(transactionData)

            } else {
                logger?.debug("Unexpected loaded page with context \(String(describing: pagination.context))")
            }
        case .loaded, .filtered:
            logger?.debug("Context loaded \(String(describing: pagination.context)) loaded but not expected")
        case let .filtering(currentPagination, prevPagination):
            if currentPagination == pagination {
                let loadedPage = Pagination(
                    count: transactionData.transactions.count,
                    context: pagination.context
                )
                dataLoadingState = WalletTransactionHistoryDataState.filtered(
                    page: loadedPage,
                    nextContext: transactionData.context
                )

                presenter?.didReceive(
                    pageData: transactionData,
                    reload: prevPagination == nil
                )

                if prevPagination == nil {
                    pages = [transactionData]
                } else {
                    pages.append(transactionData)
                }

            } else {
                logger?.debug("Context loaded \(String(describing: pagination.context)) but not expected")
            }
        }
    }

    private func handleNext(error: Error, for pagination: Pagination) {
        switch dataLoadingState {
        case .waitingCached:
            logger?.error("Cached data expected but received page error \(error)")
        case let .loading(currentPage, previousPage):
            if currentPage == pagination {
                logger?.debug("Loading page with context \(String(describing: pagination.context)) failed")

                dataLoadingState = .loaded(page: previousPage, nextContext: currentPage.context)
            } else {
                logger?.debug("Unexpected pagination context \(String(describing: pagination.context))")
            }
        case let .filtering(currentPage, previousPage):
            if currentPage == pagination {
                logger?.debug("Loading page with context \(String(describing: pagination.context)) failed")

                dataLoadingState = .filtered(page: previousPage, nextContext: currentPage.context)
            } else {
                logger?.debug("Unexpected failed page with context \(String(describing: pagination.context))")
            }
        case .loaded, .filtered:
            logger?.debug("Failed page already loaded")
        }
    }

    private func setupReloadTimer() {
        reloadTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.reloadInterval,
            repeats: true,
            block: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                let pagination = Pagination(count: strongSelf.transactionsPerPage)
                strongSelf.dataLoadingState = .filtering(page: pagination, previousPage: nil)
                strongSelf.loadTransactions(for: pagination)
            }
        )
    }

    func getUtilityAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }

    private func setupDependencies(for chainAsset: ChainAsset) {
        dependencyContainer.createDependencies(for: chainAsset, selectedAccount: selectedAccount)

        let changesBlock = { [weak self] (changes: [DataProviderChange<AssetTransactionPageData>]) -> Void in
            if let change = changes.first {
                switch change {
                case let .insert(item), let .update(item):
                    self?.handleDataProvider(transactionData: item)
                default:
                    break
                }
            } else {
                self?.handleDataProvider(transactionData: nil)
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error: Error) in
            self?.handleDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dependencyContainer.dependencies?.dataProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: failBlock,
            options: options
        )
    }
}

extension WalletTransactionHistoryInteractor: WalletTransactionHistoryInteractorInputProtocol {
    func setup() {
        setupDependencies(for: chainAsset)
        setupReloadTimer()

        presenter?.didReceive(filters: filters)

        eventCenter.add(observer: self)
    }

    func loadNext() -> Bool {
        reloadTimer?.invalidate()

        switch dataLoadingState {
        case .waitingCached:
            return false
        case let .loading(_, previousPage):
            return previousPage != nil
        case let .loaded(currentPage, context):
            if let currentPage = currentPage, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .loading(page: nextPage, previousPage: currentPage)
                loadTransactions(for: nextPage)

                return true
            } else {
                return false
            }
        case let .filtering(_, previousPage):
            return previousPage != nil
        case let .filtered(page, context):
            if let currentPage = page, context != nil {
                let nextPage = Pagination(count: transactionsPerPage, context: context)
                dataLoadingState = .filtering(page: nextPage, previousPage: currentPage)
                loadTransactions(for: nextPage)

                return true
            } else {
                return false
            }
        }
    }

    @objc func reload() {
        let pagination = Pagination(count: transactionsPerPage)
        dataLoadingState = .filtering(page: pagination, previousPage: nil)
        loadTransactions(for: pagination)
    }

    func applyFilters(_ filters: [FilterSet]) {
        self.filters = filters

        dependencyContainer.dependencies?.dataProvider?.removeObserver(self)

        let pagination = Pagination(count: transactionsPerPage)
        dataLoadingState = .filtering(page: pagination, previousPage: nil)
        loadTransactions(for: pagination)

        presenter?.didReceive(filters: filters)
    }

    func chainAssetChanged(_ newChainAsset: ChainAsset) {
        if chainAsset != newChainAsset {
            filters = WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: newChainAsset.chain)
            chainAsset = newChainAsset
            dependencyContainer.dependencies?.dataProvider?.removeObserver(self)
            setupDependencies(for: newChainAsset)
            dataLoadingState = .waitingCached
            pages = []
            reload()
        }
    }
}

extension WalletTransactionHistoryInteractor: EventVisitorProtocol {
    func processNewTransaction(event _: WalletNewTransactionInserted) {
        reload()
    }
}

extension WalletTransactionHistoryInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        reloadTimer?.invalidate()
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        setupReloadTimer()
    }
}
