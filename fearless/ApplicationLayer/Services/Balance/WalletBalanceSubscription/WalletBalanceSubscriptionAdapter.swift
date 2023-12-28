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
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletBalance(
        wallet: MetaAccountModel,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    )

    /// Collects and counts all the information for `WalletBalance`, for all meta accounts
    /// - Parameters:
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletsBalances(
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    )

    /// Collects and counts all the information for `WalletBalance`, for ChainAsset
    /// - Parameters:
    ///   - chainAsset: ChainAsset
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    )

    func subscribeChainAssetsBalance(
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    )

    func unsubscribe(listener: WalletBalanceSubscriptionListener)
}

enum WalletBalanceError: Error {
    case accountMissing
    case chainsMissing
    case `internal`
}

enum WalletBalanceListenerType {
    case wallets
    case wallet(wallet: MetaAccountModel)
    case chainAsset(wallet: MetaAccountModel, chainAsset: ChainAsset)
    case chainAssets(chainAssets: [ChainAsset], wallet: MetaAccountModel)
}

final class WalletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol, PriceLocalStorageSubscriber {
    // MARK: - PriceLocalStorageSubscriber

    static let shared = createWalletBalanceAdapter()
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private lazy var walletBalanceBuilder = {
        WalletBalanceBuilder()
    }()

    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainAssetFetcher: ChainAssetFetchingProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let logger: Logger
    private var deliverQueue: DispatchQueue?
    private var listeners: [WeakWrapper] = []
    private var expectedChainAccountsCount: Int = 0

    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private lazy var chainAssets: [ChainAssetId: ChainAsset] = [:]
    private lazy var metaAccounts: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []

    private let accountInfosLock = ReaderWriterLock()
    private let listenersLock = ReaderWriterLock()

    // MARK: - Constructor

    private init(
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAssetFetcher: ChainAssetFetchingProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: Logger
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.metaAccountRepository = metaAccountRepository
        self.chainAssetFetcher = chainAssetFetcher
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
        eventCenter.add(observer: self, dispatchIn: .main)

        fetchAllMetaAccounts()
    }

    // MARK: - Public methods

    func subscribeWalletBalance(
        wallet: MetaAccountModel,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }
        updateWalletsIfNeeded(with: wallet)
        Task {
            let cas = await getChainAssets()
            if let balances = buildBalance(for: [wallet], chainAssets: cas) {
                notify(listener: listener, result: .success(balances))
            }
        }
    }

    func subscribeWalletsBalances(
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
        let weakListener = WeakWrapper(target: listener)
        listenersLock.exclusivelyWrite { [weak self] in
            self?.listeners.append(weakListener)
        }
        Task {
            let cas = await getChainAssets()
            if let balances = buildBalance(for: metaAccounts, chainAssets: cas) {
                notify(listener: listener, result: .success(balances))
            }
        }
    }

    func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
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
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
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
        let accountInfos = accountInfosLock.concurrentlyRead {
            self.accountInfos
        }

        let walletBalances = walletBalanceBuilder.buildBalance(
            for: accountInfos,
            wallets,
            chainAssets,
            prices
        )
        return walletBalances
    }

    private func handle(_ wallets: [MetaAccountModel], _ chainAssets: [ChainAsset]) {
        let chainsAssetsMap = chainAssets.reduce(
            [ChainAssetId: ChainAsset]()
        ) { (result, chainAsset) -> [ChainAssetId: ChainAsset] in
            var dic = result

            let key = chainAsset.chainAssetId
            dic[key] = chainAsset

            return dic
        }

        self.chainAssets = chainsAssetsMap
        metaAccounts = (metaAccounts + wallets).uniq(predicate: { $0.metaId })
        defineExpectedAccountInfosCount(wallets: metaAccounts, chainAssets: chainAssets)
        subscribeToAccountInfo(for: wallets, chainAssets)
        let currencies = metaAccounts.map { $0.selectedCurrency }
        subscribeToPrices(for: chainAssets, currencies: currencies)
    }

    private func fetchAllMetaAccounts() {
        accountInfosLock.exclusivelyWrite { [weak self] in
            self?.accountInfos = [:]
        }
        let metaAccountsOperation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainsOperation = fetchChainsOperation()

        metaAccountsOperation.addDependency(chainsOperation)
        let unwrappedListeners = listenersLock.concurrentlyRead {
            listeners.compactMap {
                if let target = $0.target as? WalletBalanceSubscriptionListener {
                    return target
                }
                return nil
            }
        }

        metaAccountsOperation.completionBlock = { [weak self] in
            guard let metaAccountsResult = metaAccountsOperation.result else {
                unwrappedListeners.forEach {
                    self?.notify(listener: $0, result: .failure(WalletBalanceError.accountMissing))
                }
                return
            }
            guard let chainsResult = chainsOperation.result else {
                unwrappedListeners.forEach {
                    self?.notify(listener: $0, result: .failure(WalletBalanceError.chainsMissing))
                }
                return
            }

            switch (metaAccountsResult, chainsResult) {
            case let (.success(wallets), .success(chainAssets)):
                self?.handle(wallets, chainAssets)
            case let (.failure(error), _):
                unwrappedListeners.forEach {
                    self?.notify(listener: $0, result: .failure(error))
                }
            case let (_, .failure(error)):
                unwrappedListeners.forEach {
                    self?.notify(listener: $0, result: .failure(error))
                }
            }
        }

        operationQueue.addOperations([chainsOperation, metaAccountsOperation], waitUntilFinished: false)
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
            accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)
        }
    }

    private func defineExpectedAccountInfosCount(wallets: [MetaAccountModel], chainAssets: [ChainAsset]) {
        var chainAccounts: [ChainAccountResponse] = []
        wallets.forEach { wallet in
            let walletChainAccounts = chainAssets.compactMap { chainAsset in
                wallet.fetch(for: chainAsset.chain.accountRequest())
            }
            chainAccounts.append(contentsOf: walletChainAccounts)
        }
        expectedChainAccountsCount = chainAccounts.count
    }

    private func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?) {
        var uniqueQurrencies: [Currency]? = currencies
        if let currencies = currencies {
            uniqueQurrencies = Array(Set(currencies))
        }
        pricesProvider = subscribeToPrices(for: chainAssets, currencies: uniqueQurrencies)
    }

    private func fetchChainsOperation() -> BaseOperation<[ChainAsset]> {
        chainAssetFetcher.fetchAwaitOperation(shouldUseCache: true, filters: [], sortDescriptors: [])
    }

    private func notify(
        listener: WalletBalanceSubscriptionListener,
        result: WalletBalancesResult
    ) {
        clearIfNeeded()
        dispatchInQueueWhenPossible(deliverQueue) {
            listener.handle(result: result)
        }
    }

    private func buildAndNotifyIfNeeded(with updatedWallets: [MetaAccountModel], updatedChainAssets: [ChainAsset]) {
        clearIfNeeded()

        let unwrappedListeners = listenersLock.concurrentlyRead {
            listeners.compactMap {
                if let target = $0.target as? WalletBalanceSubscriptionListener {
                    return target
                }
                return nil
            }
        }

        Task {
            let cas = await getChainAssets()
            unwrappedListeners.forEach { listener in
                switch listener.type {
                case .wallets:
                    if let balances = buildBalance(for: metaAccounts, chainAssets: cas) {
                        notify(listener: listener, result: .success(balances))
                    }
                case let .wallet(wallet):
                    if updatedWallets.contains(wallet) {
                        if let balances = buildBalance(for: [wallet], chainAssets: cas) {
                            notify(listener: listener, result: .success(balances))
                        }
                    }
                case let .chainAsset(wallet, chainAsset):
                    if updatedWallets.contains(wallet), updatedChainAssets.contains(chainAsset) {
                        if let balances = buildBalance(for: [wallet], chainAssets: [chainAsset]) {
                            notify(listener: listener, result: .success(balances))
                        }
                    }

                case let .chainAssets(chainAssets, wallet):
                    if updatedWallets.contains(wallet), Set(chainAssets).intersection(Set(updatedChainAssets)).isNotEmpty {
                        if let balances = buildBalance(for: [wallet], chainAssets: chainAssets) {
                            notify(listener: listener, result: .success(balances))
                        }
                    }
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

    private func getChainAssets(shouldUseCache: Bool = true) async -> [ChainAsset] {
        let cas = chainAssets.map { $0.value }
        if cas.isNotEmpty, shouldUseCache {
            return cas
        } else {
            let cas = try? await chainAssetFetcher.fetchAwait(
                shouldUseCache: shouldUseCache,
                filters: [],
                sortDescriptors: []
            )
            return cas ?? []
        }
    }

    private func updateWalletsIfNeeded(with wallet: MetaAccountModel) {
        if let index = metaAccounts.firstIndex(where: { $0.metaId == wallet.metaId }), metaAccounts[index] != wallet {
            metaAccounts[index] = wallet
            Task {
                let cas = await getChainAssets()
                handle([wallet], cas)
            }
        }
    }
}

// MARK: - EventVisitorProtocol

extension WalletBalanceSubscriptionAdapter: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        if let index = metaAccounts.firstIndex(where: { $0.metaId == event.account.metaId }) {
            metaAccounts[index] = event.account
        }

        let cas = chainAssets.map { $0.value }
        let currencies = metaAccounts.map { $0.selectedCurrency }
        subscribeToPrices(for: cas, currencies: currencies)
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        let existingWalletsIds = metaAccounts.compactMap { $0.metaId }
        guard !existingWalletsIds.contains(event.account.metaId) else {
            return
        }

        Task {
            let cas = await getChainAssets()
            handle([event.account], cas)
        }
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +)

        updatedChainAssets.forEach { chainAsset in
            let key = chainAsset.chainAssetId
            self.chainAssets[key] = chainAsset
        }
        buildAndNotifyIfNeeded(with: metaAccounts, updatedChainAssets: updatedChainAssets)
    }

    func processLogout() {
        metaAccounts = []
        accountInfosAdapters.values.forEach { adapter in
            adapter.reset()
        }
        accountInfosAdapters = [:]
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        Task {
            let cas = await getChainAssets(shouldUseCache: false)
            let chainsAssetsMap = cas.reduce(
                [ChainAssetId: ChainAsset]()
            ) { (result, chainAsset) -> [ChainAssetId: ChainAsset] in
                var dic = result

                let key = chainAsset.chainAssetId
                dic[key] = chainAsset

                return dic
            }
            self.chainAssets = chainsAssetsMap
            defineExpectedAccountInfosCount(wallets: metaAccounts, chainAssets: cas)
            subscribeToAccountInfo(for: metaAccounts, cas)
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            accountInfosLock.exclusivelyWrite {
                self.accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            }
            accountInfosLock.concurrentlyRead {
                guard expectedChainAccountsCount == accountInfos.keys.count else {
                    if chainAssets.count == 1, chainAsset.chain.isEquilibrium {
                        buildAndNotifyIfNeeded(with: metaAccounts, updatedChainAssets: chainAssets.map { $0.value })
                    }
                    return
                }
                buildAndNotifyIfNeeded(with: metaAccounts, updatedChainAssets: chainAssets.map { $0.value })
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
        let unwrappedListeners = listenersLock.concurrentlyRead {
            listeners.compactMap {
                if let target = $0.target as? WalletBalanceSubscriptionListener {
                    return target
                }

                return nil
            }
        }

        switch result {
        case let .success(prices):
            Task {
                self.prices = prices
                let cas = await getChainAssets()
                buildAndNotifyIfNeeded(with: metaAccounts, updatedChainAssets: cas)
            }
        case let .failure(error):
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
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let logger = Logger.shared

        return WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAssetFetcher: chainAssetFetching,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            logger: logger
        )
    }
}
