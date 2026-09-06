import UIKit

import RobinHood
import SoraFoundation
import SSFModels

final class WalletTransactionHistoryInteractor {
    private enum Constants {
        static let reloadInterval: TimeInterval = 30.0
    }

    weak var presenter: WalletTransactionHistoryInteractorOutputProtocol?
    private let dependencyContainer: WalletTransactionHistoryDependencyContaining
    let logger: LoggerProtocol?
    var defaultFilter: WalletHistoryRequest
    var chainAsset: ChainAsset
    var selectedAccount: MetaAccountModel
    private(set) var selectedFilter: WalletHistoryRequest
    var filters: [FilterSet]
    let transactionsPerPage: Int
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandler

    private(set) var dataLoadingState: WalletTransactionHistoryDataState = .waitingCached
    private(set) var pages: [AssetTransactionPageData] = []

    private var reloadTimer: Timer?
    private var contextGeneration: UInt64 = 0
    private var requestGeneration: UInt64 = 0
    private var historyRecoveryNeeded = false

    private enum LoadingError: Error { case unavailable }

    init(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        dependencyContainer: WalletTransactionHistoryDependencyContaining,
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
        requestGeneration &+= 1
        let generation = requestGeneration
        let context = contextGeneration
        guard let utilityChainAsset = getUtilityAsset(for: chainAsset),
              let address = UniversalWalletAccountAddressResolver.address(for: utilityChainAsset.chain, wallet: selectedAccount),
              let service = dependencyContainer.dependencies?.historyService else {
            handleNext(error: LoadingError.unavailable, for: pagination)
            return
        }

        let filterValues = filters.compactMap { $0.items as? [WalletTransactionHistoryFilter] }.reduce([], +)
        service.fetchTransactionHistory(
            for: address, asset: chainAsset.asset, chain: chainAsset.chain, filters: filterValues,
            pagination: pagination, runCompletionIn: .main
        ) { [weak self] optionalResult in
            guard let self, generation == self.requestGeneration, context == self.contextGeneration else { return }
            switch optionalResult {
            case let .success(pageData?):
                self.handleNext(transactionData: pageData, for: pagination)
            case let .failure(error):
                self.handleNext(error: error, for: pagination)
            default:
                self.handleNext(error: LoadingError.unavailable, for: pagination)
            }
        }
    }

    private func handleDataProvider(transactionData: AssetTransactionPageData?) {
        switch dataLoadingState {
        case .waitingCached:
            historyRecoveryNeeded = false
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
            historyRecoveryNeeded = false
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

    func handleDataProvider(error _: Error) {
        switch dataLoadingState {
        case .waitingCached:
            dataLoadingState = .loaded(page: nil, nextContext: nil)
        case let .loading(currentPage, previousPage):
            dataLoadingState = .loaded(page: previousPage, nextContext: currentPage.context)
        case .loaded:
            break
        default:
            return
        }
        historyRecoveryNeeded = true
        logger?.debug("History provider refresh failed")
        presenter?.didReceiveHistoryFailure()
    }

    private func handleNext(transactionData: AssetTransactionPageData, for pagination: Pagination) {
        historyRecoveryNeeded = false
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

    private func handleNext(error _: Error, for pagination: Pagination) {
        switch dataLoadingState {
        case let .loading(currentPage, previousPage) where currentPage == pagination:
            dataLoadingState = .loaded(page: previousPage, nextContext: currentPage.context)
        case let .filtering(currentPage, previousPage) where currentPage == pagination:
            dataLoadingState = .filtered(page: previousPage, nextContext: currentPage.context)
        default:
            return
        }
        historyRecoveryNeeded = true
        logger?.debug("History page could not be loaded")
        presenter?.didReceiveHistoryFailure()
    }

    private func setupReloadTimer() {
        reloadTimer?.invalidate()
        reloadTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.reloadInterval,
            repeats: true,
            block: { [weak self] _ in
                guard let strongSelf = self, !strongSelf.historyRecoveryNeeded else {
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
        let context = contextGeneration
        do {
            try dependencyContainer.createDependencies(for: chainAsset, selectedAccount: selectedAccount)

            let changesBlock = { [weak self] (changes: [DataProviderChange<AssetTransactionPageData>]) -> Void in
                guard let self, context == self.contextGeneration else { return }
                if let change = changes.first {
                    switch change {
                    case let .insert(item), let .update(item):
                        self.handleDataProvider(transactionData: item)
                    default:
                        break
                    }
                } else {
                    self.handleDataProvider(transactionData: nil)
                }
            }

            let failBlock: (Error) -> Void = { [weak self] (error: Error) in
                guard let self, context == self.contextGeneration else { return }
                self.handleDataProvider(error: error)
            }
            guard dependencyContainer.dependencies?.dataProvider != nil else {
                reload()
                return
            }

            let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
            dependencyContainer.dependencies?.dataProvider?.addObserver(
                self,
                deliverOn: .main,
                executing: changesBlock,
                failing: failBlock,
                options: options
            )
        } catch {
            dependencyContainer.dependencies = nil
            historyRecoveryNeeded = true
            dataLoadingState = .loaded(page: nil, nextContext: nil)
            presenter?.didReceiveUnsupported()
        }
    }
}

extension WalletTransactionHistoryInteractor: WalletTransactionHistoryInteractorInputProtocol {
    func setup(with presenter: WalletTransactionHistoryInteractorOutputProtocol?) {
        self.presenter = presenter

        setupDependencies(for: chainAsset)
        setupReloadTimer()

        presenter?.didReceive(filters: filters)

        eventCenter.add(observer: self)
    }

    func loadNext() -> Bool {
        guard !historyRecoveryNeeded else { return false }
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
        historyRecoveryNeeded = false
        if dependencyContainer.dependencies == nil {
            dataLoadingState = .waitingCached
            setupDependencies(for: chainAsset)
            return
        }
        let pagination = Pagination(count: transactionsPerPage)
        dataLoadingState = .filtering(page: pagination, previousPage: nil)
        loadTransactions(for: pagination)
    }

    func applyFilters(_ filters: [FilterSet]) {
        contextGeneration &+= 1
        historyRecoveryNeeded = false
        self.filters = filters

        dependencyContainer.dependencies?.dataProvider?.removeObserver(self)

        let pagination = Pagination(count: transactionsPerPage)
        dataLoadingState = .filtering(page: pagination, previousPage: nil)
        loadTransactions(for: pagination)

        presenter?.didReceive(filters: filters)
    }

    func chainAssetChanged(_ newChainAsset: ChainAsset) {
        guard chainAsset != newChainAsset else { return }
        filters = WalletTransactionHistoryViewFactory.transactionHistoryFilters(for: newChainAsset.chain)
        chainAsset = newChainAsset
        resetHistoryContext()
    }

    func historyExplorerURL() -> URL? {
        guard let address = UniversalWalletAccountAddressResolver.address(for: chainAsset.chain, wallet: selectedAccount) else { return nil }
        for explorer in chainAsset.chain.externalApi?.explorers ?? [] {
            let type: ChainModel.SubscanType = explorer.types.contains(.address) ? .address : .account
            guard explorer.types.contains(type), let url = explorer.explorerUrl(for: address, type: type),
                  url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil else { continue }
            if chainAsset.chain.chainId == "196",
               ["www.okx.com", "web3.okx.com", "www.oklink.com", "oklink.com"].contains(host.lowercased()),
               ["/explorer/xlayer-test/", "/xlayer-test/", "/x-layer/"].contains(where: url.path.hasPrefix) {
                // The released registry used xlayer-test even for mainnet 196.
                // Keep the original account, correcting only that provider route.
                return URL(string: "https://www.oklink.com/xlayer/address/\(address)")
            }
            return url
        }
        return nil
    }

    private func resetHistoryContext() {
        contextGeneration &+= 1
        requestGeneration &+= 1
        historyRecoveryNeeded = false
        dependencyContainer.dependencies?.dataProvider?.removeObserver(self)
        dataLoadingState = .waitingCached
        pages = []
        presenter?.didResetHistory()
        setupDependencies(for: chainAsset)
    }
}

extension WalletTransactionHistoryInteractor: EventVisitorProtocol {
    func processNewTransaction(event _: WalletNewTransactionInserted) {
        reload()
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        selectedAccount = event.account
        resetHistoryContext()
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
