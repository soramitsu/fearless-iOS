import Foundation
import RobinHood
import SSFModels

typealias WalletBalanceInfos = [MetaAccountId: WalletBalanceInfo]
typealias WalletBalancesResult = Result<WalletBalanceInfos, Error>

protocol WalletBalanceSubscriptionListener: AnyObject {
    var type: WalletBalanceListenerType { get }
    func handle(result: WalletBalancesResult)
}

protocol WalletBalanceSubscriptionAdapterProtocol {
    /// Collects and counts all the information for `WalletBalance`, for specific wallet id
    /// - Parameters:
    ///   - wallet: Balance for specific wallet.
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletBalance(
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    )

    /// Collects and counts all the information for `WalletBalance`, for all meta accounts
    /// - Parameters:
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletsBalances(
        listener: WalletBalanceSubscriptionListener
    )

    /// Collects and counts all the information for `WalletBalance`, for ChainAsset
    /// - Parameters:
    ///   - chainAsset: ChainAsset
    ///   - handler: Called when WalletBalance will calculated
    func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        listener: WalletBalanceSubscriptionListener
    )

    func subscribeChainAssetsBalance(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    )

    func unsubscribe(listener: WalletBalanceSubscriptionListener)
}

enum WalletBalanceListenerType {
    case wallets
    case wallet(wallet: MetaAccountModel)
    case chainAsset(wallet: MetaAccountModel, chainAsset: ChainAsset)
    case chainAssets(chainAssets: [ChainAsset], wallet: MetaAccountModel)
}

final class WalletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol {
    static let shared = createWalletBalanceAdapter()

    // MARK: - PriceLocalStorageSubscriber

    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    // MARK: - Private properties

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private lazy var walletBalanceBuilder = {
        WalletBalanceBuilder()
    }()

    private let walletRepository: AsyncAnyRepository<MetaAccountModel>
    private let chainAssetFetcher: ChainAssetFetchingProtocol
    private let eventCenter: EventCenterProtocol
    private let logger: Logger
    private let accountInfoFetchingProvider: AccountInfoFetchingProtocol

    private lazy var listeners: [WeakWrapper] = []
    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private lazy var chainAssets: [ChainAsset] = []
    private lazy var wallets: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []

    private let listenersLock = ReaderWriterLock()
    private let accountInfoWorkQueue = DispatchQueue(
        label: "co.jp.soramitsu.wallet.balance.work.queue",
        attributes: .concurrent
    )

    // MARK: - Constructor

    private init(
        metaAccountRepository: AsyncAnyRepository<MetaAccountModel>,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAssetFetcher: ChainAssetFetchingProtocol,
        eventCenter: EventCenterProtocol,
        logger: Logger,
        accountInfoFetchingProvider: AccountInfoFetchingProtocol
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        walletRepository = metaAccountRepository
        self.chainAssetFetcher = chainAssetFetcher
        self.eventCenter = eventCenter
        self.logger = logger
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        eventCenter.add(observer: self)

        fetchInitialData()
    }

    // MARK: - Public methods

    func subscribeWalletBalance(
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    ) {
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }
        updateWalletsIfNeeded(with: wallet)
        if let balances = buildBalance(for: [wallet], chainAssets: chainAssets) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func subscribeWalletsBalances(
        listener: WalletBalanceSubscriptionListener
    ) {
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }
        if let balances = buildBalance(for: wallets, chainAssets: chainAssets) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        listener: WalletBalanceSubscriptionListener
    ) {
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }
        if let balances = buildBalance(for: [wallet], chainAssets: [chainAsset]) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func subscribeChainAssetsBalance(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    ) {
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }

        if let balances = buildBalance(for: [wallet], chainAssets: chainAssets) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func unsubscribe(listener: WalletBalanceSubscriptionListener) {
        listenersLock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.listeners = strongSelf.listeners.filter {
                if let target = $0.target as? WalletBalanceSubscriptionListener {
                    return target !== listener
                }
                return true
            }
        }
    }

    // MARK: - Private methods

    private func buildBalance(for wallets: [MetaAccountModel], chainAssets: [ChainAsset]) -> WalletBalanceInfos? {
        let walletBalances = walletBalanceBuilder.buildBalance(
            for: accountInfos,
            wallets,
            chainAssets,
            prices
        )
        return walletBalances
    }

    private func handle(_ wallets: [MetaAccountModel], _ chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
        self.wallets = (self.wallets + wallets).uniq(predicate: { $0.metaId })
        subscribeToAccountInfo(for: wallets, chainAssets)
        let currencies = wallets.map { $0.selectedCurrency }
        subscribeToPrices(for: chainAssets, currencies: currencies)
    }

    private func fetchInitialData() {
        Task {
            do {
                async let wallets = self.walletRepository.fetchAll()
                async let chainAssets = chainAssetFetcher.fetchAwait(shouldUseCache: false, filters: [], sortDescriptors: [])
                try await handle(wallets, chainAssets)

                let accountInfos = try await fetchAccountInfos(wallets: wallets, chainAssets: chainAssets)
                self.accountInfos = accountInfos
            } catch {
                let unwrappedListeners = listenersLock.concurrentlyRead {
                    listeners.compactMap {
                        if let target = $0.target as? WalletBalanceSubscriptionListener {
                            return target
                        }
                        return nil
                    }
                }
                unwrappedListeners.forEach {
                    notify(listener: $0, result: .failure(error))
                }
            }
        }
    }

    private func fetchAccountInfos(
        wallets: [MetaAccountModel],
        chainAssets: [ChainAsset]
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        let accountInfos = try await withThrowingTaskGroup(of: [ChainAssetKey: AccountInfo?].self) { group in
            wallets.forEach { wallet in
                group.addTask {
                    try await self.accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: wallet)
                }
            }

            var result = [ChainAssetKey: AccountInfo?]()
            for try await accountInfos in group {
                result.merge(accountInfos) { _, new in new }
            }
            return result
        }
        return accountInfos
    }

    private func subscribeToAccountInfo(
        for wallets: [MetaAccountModel],
        _ chainAssets: [ChainAsset]
    ) {
        let walletIds = wallets.compactMap { $0.metaId }
        accountInfosAdapters.map { $0.value }.filter { walletIds.contains($0.wallet.metaId) }.forEach { $0.reset() }

        wallets.forEach { wallet in
            let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            )
            self.accountInfosAdapters[wallet.identifier] = accountInfoSubscriptionAdapter
            accountInfoSubscriptionAdapter.subscribe(
                chainsAssets: chainAssets,
                handler: self,
                deliveryOn: accountInfoWorkQueue,
                notifyJustWhenUpdated: true
            )
        }
    }

    private func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?) {
        var uniqueQurrencies: [Currency]? = currencies
        if let currencies = currencies {
            uniqueQurrencies = Array(Set(currencies))
        }
        pricesProvider = priceLocalSubscriber.subscribeToPrices(for: chainAssets, currencies: uniqueQurrencies, listener: self)
    }

    private func notify(
        listener: WalletBalanceSubscriptionListener,
        result: WalletBalancesResult
    ) {
        clearIfNeeded()
        listener.handle(result: result)
    }

    private func buildAndNotifyIfNeeded(with updatedWalletsIds: [MetaAccountId], updatedChainAssets: [ChainAsset]) {
        clearIfNeeded()

        let unwrappedListeners = listeners.compactMap {
            if let target = $0.target as? WalletBalanceSubscriptionListener {
                return target
            }
            return nil
        }

        unwrappedListeners.forEach { listener in
            switch listener.type {
            case .wallets:
                if let balances = buildBalance(for: wallets, chainAssets: chainAssets) {
                    notify(listener: listener, result: .success(balances))
                }
            case let .wallet(wallet):
                if updatedWalletsIds.contains(wallet.metaId),
                   let balances = buildBalance(for: [wallet], chainAssets: chainAssets) {
                    notify(listener: listener, result: .success(balances))
                }
            case let .chainAsset(wallet, chainAsset):
                let updatedChainAssetsIds = updatedChainAssets.map { $0.identifier }
                if updatedWalletsIds.contains(wallet.metaId),
                   updatedChainAssetsIds.contains(chainAsset.identifier),
                   let balances = buildBalance(for: [wallet], chainAssets: [chainAsset]) {
                    notify(listener: listener, result: .success(balances))
                }
            case let .chainAssets(chainAssets, wallet):
                let updatedChainAssetsIds = updatedChainAssets.map { $0.identifier }
                let chainAssetsIds = chainAssets.map { $0.identifier }

                if updatedWalletsIds.contains(wallet.metaId),
                   Set(chainAssetsIds).intersection(Set(updatedChainAssetsIds)).isNotEmpty,
                   let balances = buildBalance(for: [wallet], chainAssets: chainAssets) {
                    notify(listener: listener, result: .success(balances))
                }
            }
        }
    }

    private func clearIfNeeded() {
        listenersLock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.listeners = strongSelf.listeners.filter { $0.target != nil }
        }
    }

    private func updateWalletsIfNeeded(with wallet: MetaAccountModel) {
        if let index = wallets.firstIndex(where: { $0.metaId == wallet.metaId }),
           wallets[index].selectedCurrency != wallet.selectedCurrency {
            wallets[index] = wallet
            handle([wallet], chainAssets)
        }
    }

    private func concurrentlyAccountInfoRead<T>(_ block: () throws -> T) rethrows -> T {
        try accountInfoWorkQueue.sync {
            try block()
        }
    }
}

// MARK: - EventVisitorProtocol

extension WalletBalanceSubscriptionAdapter: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        if let index = wallets.firstIndex(where: { $0.metaId == event.account.metaId }),
           let wallet = wallets[safe: index] {
            if wallet.selectedCurrency != event.account.selectedCurrency {
                let currencies = wallets.map { $0.selectedCurrency }
                subscribeToPrices(for: chainAssets, currencies: currencies)
            }
            wallets[index] = event.account
        }
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        let existingWalletsIds = wallets.compactMap { $0.metaId }
        guard !existingWalletsIds.contains(event.account.metaId) else {
            return
        }
        handle([event.account], chainAssets)
    }

    func processLogout() {
        wallets = []
        accountInfosAdapters.values.forEach { adapter in
            adapter.reset()
        }
        accountInfosAdapters = [:]
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        Task {
            let chainAssets = try await chainAssetFetcher.fetchAwait(
                shouldUseCache: false,
                filters: [],
                sortDescriptors: []
            )
            subscribeToAccountInfo(for: wallets, chainAssets)
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            accountInfoWorkQueue.async(flags: .barrier) {
                let key = chainAsset.uniqueKey(accountId: accountId)
                let previousAccountInfo = self.accountInfos[key] ?? nil

                self.accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo

                let bothNil = (previousAccountInfo == nil && accountInfo == nil)

                guard previousAccountInfo != accountInfo, !bothNil else {
                    return
                }
                self.buildAndNotifyIfNeeded(with: self.wallets.map { $0.metaId }, updatedChainAssets: self.chainAssets)
            }
        case let .failure(error):
            logger.error("""
                WalletBalanceFetcher error: \(error.localizedDescription)
                account: \(accountId),
                chainAsset: \(chainAsset.debugName)
                """
            )
        }
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension WalletBalanceSubscriptionAdapter: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            self.prices = prices
            buildAndNotifyIfNeeded(with: wallets.map { $0.metaId }, updatedChainAssets: chainAssets)
        case let .failure(error):
            let unwrappedListeners = listenersLock.concurrentlyRead {
                listeners.compactMap {
                    if let target = $0.target as? WalletBalanceSubscriptionListener {
                        return target
                    }

                    return nil
                }
            }
            unwrappedListeners.forEach { listener in
                notify(listener: listener, result: .failure(error))
            }
            logger.error("WalletBalanceFetcher error: \(error.localizedDescription)")
        }
    }
}

private extension WalletBalanceSubscriptionAdapter {
    static func createWalletBalanceAdapter() -> WalletBalanceSubscriptionAdapter {
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepositoryAsync = accountRepositoryFactory.createAsyncMetaAccountRepository(for: nil, sortDescriptors: [])
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let logger = Logger.shared

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationQueue()
        )

        return WalletBalanceSubscriptionAdapter(
            metaAccountRepository: accountRepositoryAsync,
            priceLocalSubscriber: priceLocalSubscriber,
            chainAssetFetcher: chainAssetFetching,
            eventCenter: EventCenter.shared,
            logger: logger,
            accountInfoFetchingProvider: accountInfoFetching
        )
    }
}
