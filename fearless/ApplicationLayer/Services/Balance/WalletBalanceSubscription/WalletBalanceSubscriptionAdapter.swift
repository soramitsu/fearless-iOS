import Foundation
import RobinHood
import SSFModels

typealias WalletBalanceInfos = [MetaAccountId: WalletBalanceInfo]
typealias WalletBalancesResult = Result<WalletBalanceInfos, Error>

protocol WalletBalanceSubscriptionListener: AnyObject {
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
}

final class WalletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol, PriceLocalStorageSubscriber {
    private struct Listener {
        let listener: WalletBalanceSubscriptionListener
        let type: WalletBalanceListenerType
    }

    // MARK: - PriceLocalStorageSubscriber

    static let shared = WalletBalanceSubscriptionFactory.createWalletBalanceAdapter()
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
    private var listeners: [Listener] = []
    private var accountInfoTimer: Timer?

    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private lazy var chainAssets: [ChainAssetId: ChainAsset] = [:]
    private lazy var metaAccounts: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []

    private let lock = ReaderWriterLock()

    // MARK: - Constructor

    init(
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
        listeners.append(Listener(listener: listener, type: .wallet(wallet: wallet)))

        if let balances = buildBalance(for: [wallet], chainAssets: chainAssets.map { $0.value }) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func subscribeWalletsBalances(
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
        listeners.append(Listener(listener: listener, type: .wallets))

        if let balances = buildBalance(for: metaAccounts, chainAssets: chainAssets.map { $0.value }) {
            notify(listener: listener, result: .success(balances))
        }
    }

    func subscribeChainAssetBalance(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        deliverOn queue: DispatchQueue?,
        listener: WalletBalanceSubscriptionListener
    ) {
        deliverQueue = queue
        listeners.append(Listener(listener: listener, type: .chainAsset(wallet: wallet, chainAsset: chainAsset)))

        if let balances = buildBalance(for: [wallet], chainAssets: [chainAsset]) {
            notify(listener: listener, result: .success(balances))
        }
    }

    // MARK: - Private methods

    private func buildBalance(for wallets: [MetaAccountModel], chainAssets: [ChainAsset]) -> WalletBalanceInfos? {
        print("build balance: \(accountInfos.count), \(wallets.count), \(chainAssets.count), \(prices.count)")
        let walletBalances = walletBalanceBuilder.buildBalance(
            for: accountInfos,
            wallets,
            chainAssets,
            prices
        )
        let totalBalance = walletBalances?.values.map { $0.totalFiatValue }
        print("build balance result: \(String(describing: totalBalance))")

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
        metaAccounts = wallets

        subscribeToAccountInfo(for: wallets, chainAssets)
        let currencies = wallets.map { $0.selectedCurrency }
        subscribeToPrices(for: chainAssets, currencies: currencies)
    }

    private func fetchAllMetaAccounts() {
        let metaAccountsOperation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainsOperation = fetchChainsOperation()

        metaAccountsOperation.addDependency(chainsOperation)

        metaAccountsOperation.completionBlock = { [weak self] in
            guard let metaAccountsResult = metaAccountsOperation.result else {
                self?.listeners.map { $0.listener }.forEach { [weak self] in
                    self?.notify(listener: $0, result: .failure(WalletBalanceError.accountMissing))
                }
                return
            }
            guard let chainsResult = chainsOperation.result else {
                self?.listeners.map { $0.listener }.forEach { [weak self] in
                    self?.notify(listener: $0, result: .failure(WalletBalanceError.chainsMissing))
                }
                return
            }

            switch (metaAccountsResult, chainsResult) {
            case let (.success(wallets), .success(chainAssets)):
                self?.handle(wallets, chainAssets)
            case let (.failure(error), _):
                self?.listeners.map { $0.listener }.forEach { [weak self] in
                    self?.notify(listener: $0, result: .failure(error))
                }
            case let (_, .failure(error)):
                self?.listeners.map { $0.listener }.forEach { [weak self] in
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
        wallets.forEach { wallet in
            let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            )
            self.accountInfosAdapters[wallet.identifier] = accountInfoSubscriptionAdapter
            accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)
        }
    }

    private func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId)
        var uniqueQurrencies: [Currency]? = currencies
        if let currencies = currencies {
            uniqueQurrencies = Array(Set(currencies))
        }
        pricesProvider = subscribeToPrices(for: pricesIds, currencies: uniqueQurrencies)
    }

    private func fetchChainsOperation() -> BaseOperation<[ChainAsset]> {
        chainAssetFetcher.fetchAwaitOperation(shouldUseCashe: true, filters: [], sortDescriptors: [])
    }

    private func notify(
        listener: WalletBalanceSubscriptionListener,
        result: WalletBalancesResult
    ) {
        dispatchInQueueWhenPossible(deliverQueue) {
            listener.handle(result: result)
        }
    }

    private func notifyIfNeeded(with updatedWallets: [MetaAccountModel], updatedChainAssets: [ChainAsset]) {
        print("notifyIfNeeded, walletsCount: \(updatedWallets.count)")
        listeners.forEach { listener in
            switch listener.type {
            case .wallets:
                if let balances = buildBalance(for: self.metaAccounts, chainAssets: self.chainAssets.map { $0.value }) {
                    notify(listener: listener.listener, result: .success(balances))
                    let totalBalance = balances.map { _, value in
                        value.totalFiatValue
                    }
                }
            case let .wallet(wallet):
                if updatedWallets.contains(wallet) {
                    if let balances = buildBalance(for: [wallet], chainAssets: self.chainAssets.map { $0.value }) {
                        notify(listener: listener.listener, result: .success(balances))
                        let totalBalance = balances.map { _, value in
                            value.totalFiatValue
                        }
                    }
                }
            case let .chainAsset(wallet, chainAsset):
                if updatedWallets.contains(wallet), updatedChainAssets.contains(chainAsset) {
                    if let balances = buildBalance(for: [wallet], chainAssets: [chainAsset]) {
                        notify(listener: listener.listener, result: .success(balances))
                        let totalBalance = balances.map { _, value in
                            value.totalFiatValue
                        }
                    }
                }
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
        pricesProvider?.refresh()
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        fetchAllMetaAccounts()
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +)

        updatedChainAssets.forEach { chainAsset in
            let key = chainAsset.chainAssetId
            self.chainAssets[key] = chainAsset
        }
        notifyIfNeeded(with: metaAccounts, updatedChainAssets: updatedChainAssets)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        if let timer = accountInfoTimer {
            timer.invalidate()
        }
        accountInfoTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { [weak self] timer in
            guard let strongSelf = self else { return }
            strongSelf.notifyIfNeeded(with: strongSelf.metaAccounts, updatedChainAssets: strongSelf.chainAssets.map { $0.value })
            timer.invalidate()
        })
        switch result {
        case let .success(accountInfo):
            lock.exclusivelyWrite {
                self.accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
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
            notifyIfNeeded(with: metaAccounts, updatedChainAssets: chainAssets.map { $0.value })
        case let .failure(error):
            listeners.forEach { listener in
                notify(listener: listener.listener, result: .failure(error))
            }
            logger.error("WalletBalanceFetcher error: \(error.localizedDescription)")
        }
    }
}
