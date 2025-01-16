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

    func subscribeNetworkManagementBalance(
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
    case networkManagement(wallet: MetaAccountModel)
}

final actor WalletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol, ChainAssetListBuilder {
    static let shared = createWalletBalanceAdapter()

    // MARK: - Private properties

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

    private let listenersLock = ReaderWriterLock()
    private let accountInfoWorkQueue = DispatchQueue(
        label: "co.jp.soramitsu.wallet.balance.work.queue",
        attributes: .concurrent
    )

    // MARK: - Constructor

    private init(
        metaAccountRepository: AsyncAnyRepository<MetaAccountModel>,
        chainAssetFetcher: ChainAssetFetchingProtocol,
        eventCenter: EventCenterProtocol,
        logger: Logger,
        accountInfoFetchingProvider: AccountInfoFetchingProtocol
    ) {
        walletRepository = metaAccountRepository
        self.chainAssetFetcher = chainAssetFetcher
        self.eventCenter = eventCenter
        self.logger = logger
        self.accountInfoFetchingProvider = accountInfoFetchingProvider
        eventCenter.add(observer: self)

        Task {
            await fetchInitialData()
        }
    }
    
    private func addListener(_ listener: WeakWrapper) async {
        listeners.append(listener)
    }
    
    private func removeListener(_ listener: WalletBalanceSubscriptionListener) async {
        listeners = listeners.filter {
            if let target = $0.target as? WalletBalanceSubscriptionListener {
                return target !== listener
            }
            return true
        }
    }
    
    private func saveAccountInfoAdapters(_ accountInfosAdapters: [String: AccountInfoSubscriptionAdapter]) async {
        self.accountInfosAdapters = accountInfosAdapters
    }
    
    private func saveWallets(_ wallets: [MetaAccountModel]) async {
        self.wallets = wallets
    }
    
    private func saveChainAssets(_ chainAssets: [ChainAsset]) async {
        self.chainAssets = chainAssets
    }
    
    private func saveAccountInfos(accountInfos: [ChainAssetKey: AccountInfo?]) async {
        self.accountInfos = accountInfos
    }

    // MARK: - Public methods

    nonisolated func subscribeWalletBalance(
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    ) {
        Task {
            try await updateLocalBalances(wallets: [wallet], chainAssets: chainAssets)

            let weakListener = WeakWrapper(target: listener)
            Task {
                await addListener(weakListener)
            }
            
            await updateWalletsIfNeeded(with: wallet)
            if let balances = await buildBalance(for: [wallet], chainAssets: chainAssets) {
                await notify(listener: listener, result: .success(balances))
            }
        }
    }

    nonisolated func subscribeWalletsBalances(
        listener: WalletBalanceSubscriptionListener
    ) {
        Task {
            try await updateLocalBalances(wallets: wallets, chainAssets: chainAssets)

            let weakListener = WeakWrapper(target: listener)
            Task {
                await addListener(weakListener)
            }
            if let balances = await buildBalance(for: wallets, chainAssets: chainAssets) {
                await notify(listener: listener, result: .success(balances))
            }
        }
    }

    nonisolated func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        listener: WalletBalanceSubscriptionListener
    ) {
        Task {
            try await updateLocalBalances(wallets: [wallet], chainAssets: [chainAsset])

            let weakListener = WeakWrapper(target: listener)
            Task {
                await addListener(weakListener)
            }
            if let balances = await buildBalance(for: [wallet], chainAssets: [chainAsset]) {
                await notify(listener: listener, result: .success(balances))
            }
        }
    }

    nonisolated func subscribeChainAssetsBalance(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    ) {
        Task {
            try await updateLocalBalances(wallets: [wallet], chainAssets: chainAssets)

            let weakListener = WeakWrapper(target: listener)
            Task {
                await addListener(weakListener)
            }

            if let balances = await buildBalance(for: [wallet], chainAssets: chainAssets) {
                await notify(listener: listener, result: .success(balances))
            }
        }
    }

    nonisolated func subscribeNetworkManagementBalance(
        wallet: MetaAccountModel,
        listener: WalletBalanceSubscriptionListener
    ) {
        Task {
            try await updateLocalBalances(wallets: [wallet], chainAssets: chainAssets)

            let weakListener = WeakWrapper(target: listener)
            Task {
                await addListener(weakListener)
            }
            await updateWalletsIfNeeded(with: wallet)
            let selectedChainAssets = await filterChainAssets(
                with: NetworkManagmentFilter(identifier: wallet.networkManagmentFilter),
                chainAssets: chainAssets,
                wallet: wallet,
                search: nil
            )

            if let balances = await buildBalance(for: [wallet], chainAssets: selectedChainAssets) {
                await notify(listener: listener, result: .success(balances))
            }
        }
    }

    nonisolated func unsubscribe(listener: WalletBalanceSubscriptionListener) {
        Task {
            await removeListener(listener)
        }
    }

    // MARK: - Private methods

    private func updateLocalBalances(wallets: [MetaAccountModel], chainAssets: [ChainAsset]) async throws {
        let accountInfos = try await fetchAccountInfos(wallets: wallets, chainAssets: chainAssets)
        self.accountInfos = self.accountInfos.merging(accountInfos, uniquingKeysWith: { _, new in
            new
        })
    }

    private func buildBalance(for wallets: [MetaAccountModel], chainAssets: [ChainAsset]) -> WalletBalanceInfos? {
        let walletBalances = walletBalanceBuilder.buildBalance(
            for: accountInfos,
            wallets,
            chainAssets
        )
        return walletBalances
    }

    private func handle(_ wallets: [MetaAccountModel], _ chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
        self.wallets = (self.wallets + wallets).uniq(predicate: { $0.metaId })
        subscribeToAccountInfo(for: wallets, chainAssets)
    }

    private func fetchInitialData() {
        Task {
            do {
                async let wallets = self.walletRepository.fetchAll()
                async let chainAssets = chainAssetFetcher.fetchAwait(shouldUseCache: false, filters: [.enabledChains], sortDescriptors: [])
                try await handle(wallets, chainAssets)

                let accountInfos = try await fetchAccountInfos(wallets: wallets, chainAssets: chainAssets)
                self.accountInfos = accountInfos
                self.buildAndNotifyIfNeeded(with: try await wallets.map { $0.metaId }, updatedChainAssets: try await chainAssets)
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
        let accountInfos = try await wallets.concurrentMap { wallet in
            do {
                return try await self.accountInfoFetchingProvider.fetchByUniqKey(for: chainAssets, wallet: wallet)
            } catch {
                return [:]
            }
        }
        let result = Dictionary(accountInfos.flatMap { $0 }, uniquingKeysWith: { _, last in last })
        return result
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

    private func notify(
        listener: WalletBalanceSubscriptionListener,
        result: WalletBalancesResult
    ) {
        Task {
            await clearIfNeeded()
            listener.handle(result: result)
        }
    }

    private func buildAndNotifyIfNeeded(with updatedWalletsIds: [MetaAccountId], updatedChainAssets: [ChainAsset]) {
        Task {
            await clearIfNeeded()
        }
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
            case let .networkManagement(wallet):
                let selectedChainAssets = filterChainAssets(
                    with: NetworkManagmentFilter(identifier: wallet.networkManagmentFilter),
                    chainAssets: chainAssets,
                    wallet: wallet,
                    search: nil
                )
                if updatedWalletsIds.contains(wallet.metaId),
                   let balances = buildBalance(for: [wallet], chainAssets: selectedChainAssets) {
                    notify(listener: listener, result: .success(balances))
                }
            }
        }
    }

    private func clearIfNeeded() async {
        listeners = listeners.filter { $0.target != nil }
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
    nonisolated func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        Task {
            var wallets = await self.wallets
            if let index = wallets.firstIndex(where: { $0.metaId == event.account.metaId }),
               let wallet = wallets[safe: index] {
                if wallet.selectedCurrency != event.account.selectedCurrency {
                    wallets[index] = event.account
                }
                if wallet.networkManagmentFilter != event.account.networkManagmentFilter {
                    wallets[index] = event.account
                    await buildAndNotifyIfNeeded(with: [wallet.metaId], updatedChainAssets: chainAssets)
                }
                wallets[index] = event.account
                
                await saveWallets(wallets)
            }
        }
    }

    nonisolated func processSelectedAccountChanged(event: SelectedAccountChanged) {
        Task {
            let existingWalletsIds = await wallets.compactMap { $0.metaId }
            guard !existingWalletsIds.contains(event.account.metaId) else {
                return
            }
            await handle([event.account], chainAssets)
        }
    }

    nonisolated func processLogout() {
        Task {
            await saveWallets([])
            await accountInfosAdapters.values.forEach { adapter in
                adapter.reset()
            }
            await saveAccountInfoAdapters([:])
        }
    }

    nonisolated func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        Task {
            let chainAssets = try await chainAssetFetcher.fetchAwait(
                shouldUseCache: false,
                filters: [.enabledChains],
                sortDescriptors: []
            )
            await subscribeToAccountInfo(for: wallets, chainAssets)
        }
    }

    nonisolated func processPricesUpdated() {
        Task {
            let chainAssets = try await chainAssetFetcher.fetchAwait(
                shouldUseCache: false,
                filters: [.enabledChains],
                sortDescriptors: []
            )
            
            await saveChainAssets(chainAssets)
            await buildAndNotifyIfNeeded(with: wallets.map { $0.metaId }, updatedChainAssets: chainAssets)
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    nonisolated func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            Task {
                let key = chainAsset.uniqueKey(accountId: accountId)
                let previousAccountInfo = await self.accountInfos[key] ?? nil

                var accountInfos = await self.accountInfos
                accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
                await saveAccountInfos(accountInfos: accountInfos)

                let bothNil = (previousAccountInfo == nil && accountInfo == nil)

                guard previousAccountInfo != accountInfo, !bothNil else {
                    return
                }
                await self.buildAndNotifyIfNeeded(with: self.wallets.map { $0.metaId }, updatedChainAssets: self.chainAssets)
            }
        case let .failure(error):
            Task {
                await logger.error("""
                    WalletBalanceFetcher error: \(error.localizedDescription)
                    account: \(accountId),
                    chainAsset: \(chainAsset.debugName)
                    """
                )
            }
        }
    }
}

private extension WalletBalanceSubscriptionAdapter {
    static func createWalletBalanceAdapter() -> WalletBalanceSubscriptionAdapter {
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepositoryAsync = accountRepositoryFactory.createAsyncMetaAccountRepository(for: nil, sortDescriptors: [])

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
            chainAssetFetcher: chainAssetFetching,
            eventCenter: EventCenter.shared,
            logger: logger,
            accountInfoFetchingProvider: accountInfoFetching
        )
    }
}
