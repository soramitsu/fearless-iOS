import Foundation
import RobinHood
import SSFModels

typealias WalletBalanceInfos = [MetaAccountId: WalletBalanceInfo]
typealias WalletBalancesResult = Result<WalletBalanceInfos, Error>

protocol WalletBalanceSubscriptionHandler: AnyObject {
    func handle(result: WalletBalancesResult)
}

protocol WalletBalanceSubscriptionAdapterProtocol {
    /// Collects and counts all the information for `WalletBalance`, for specific wallet id
    /// - Parameters:
    ///   - walletId: Balance for specific wallet Id.
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletBalance(
        walletId: String,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    )

    /// Collects and counts all the information for `WalletBalance`, for all meta accounts
    /// - Parameters:
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeWalletsBalances(
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    )

    /// Collects and counts all the information for `WalletBalance`, for ChainAsset
    /// - Parameters:
    ///   - chainAsset: ChainAsset
    ///   - queue: The queue to which the result will be delivered
    ///   - handler: Called when WalletBalance will calculated
    func subscribeChainAssetBalance(
        walletId: String,
        chainAsset: ChainAsset,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    )
}

enum WalletBalanceError: Error {
    case accountMissing
    case chainsMissing
    case `internal`
}

enum WalletBalanceSubscriptionType {
    case wallets
    case wallet(walletId: String)
    case chainAsset(walletId: String, chainAsset: ChainAsset)
}

final class WalletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol, PriceLocalStorageSubscriber {
    // MARK: - PriceLocalStorageSubscriber

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private lazy var walletBalanceBuilder = {
        WalletBalanceBuilder()
    }()

    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let logger: Logger
    private var deliverQueue: DispatchQueue?
    private weak var delegate: WalletBalanceSubscriptionHandler?

    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private lazy var chainAssets: [ChainAssetId: ChainAsset] = [:]
    private lazy var metaAccounts: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []
    private var subscriptionType: WalletBalanceSubscriptionType?

    private let lock = ReaderWriterLock()

    // MARK: - Constructor

    init(
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: Logger
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.metaAccountRepository = metaAccountRepository
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
        eventCenter.add(observer: self, dispatchIn: .main)
    }

    // MARK: - Public methods

    func subscribeWalletBalance(
        walletId: String,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    ) {
        subscriptionType = .wallet(walletId: walletId)

        reset()
        deliverQueue = queue
        delegate = handler

        fetchMetaAccount(by: walletId, chainAsset: nil)
    }

    func subscribeWalletsBalances(
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    ) {
        subscriptionType = .wallets

        reset()
        deliverQueue = queue
        delegate = handler

        fetchAllMetaAccounts()
    }

    func subscribeChainAssetBalance(
        walletId: String,
        chainAsset: ChainAsset,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceSubscriptionHandler
    ) {
        subscriptionType = .chainAsset(walletId: walletId, chainAsset: chainAsset)

        reset()
        deliverQueue = queue
        delegate = handler

        fetchMetaAccount(by: walletId, chainAsset: chainAsset)
    }

    // MARK: - Private methods

    private func reset() {
        accountInfos = [:]
        metaAccounts.forEach { wallet in
            accountInfosAdapters[wallet.identifier]?.reset()
        }
        accountInfosAdapters = [:]
    }

    private func buildBalance() {
        let walletBalances = walletBalanceBuilder.buildBalance(
            for: accountInfos,
            metaAccounts,
            chainAssets.values.map { $0 },
            prices
        )

        guard let walletBalances = walletBalances else {
            return
        }

        handle(.success(walletBalances))
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
        subscribeToPrices(for: chainAssets)
    }

    private func fetchMetaAccount(by identifier: String, chainAsset: ChainAsset?) {
        typealias MergeOperationResult = (metaAccount: MetaAccountModel?, chains: [ChainModel])

        let metaAccountOperation = metaAccountRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )
        let chainsOperation = fetchChainsOperation()

        let mergeOperation = ClosureOperation<MergeOperationResult> {
            let metaAccountOperationResult = try metaAccountOperation.extractNoCancellableResultData()
            let chainsOperationResult = try chainsOperation.extractNoCancellableResultData()

            return (metaAccount: metaAccountOperationResult, chains: chainsOperationResult)
        }

        mergeOperation.completionBlock = { [weak self] in
            guard let result = mergeOperation.result else {
                self?.handle(.failure(WalletBalanceError.internal))
                return
            }

            switch result {
            case let .success((metaAccount, chains)):
                guard let wallet = metaAccount else {
                    self?.handle(.failure(WalletBalanceError.accountMissing))
                    return
                }

                var chainAssets: [ChainAsset] = []
                if let chainAsset = chainAsset {
                    chainAssets.append(chainAsset)
                } else {
                    chainAssets = chains.map(\.chainAssets).reduce([], +)
                }
                self?.handle([wallet], chainAssets)
            case let .failure(error):
                self?.handle(.failure(error))
            }
        }

        mergeOperation.addDependency(metaAccountOperation)
        mergeOperation.addDependency(chainsOperation)

        operationQueue.addOperations([chainsOperation, metaAccountOperation, mergeOperation], waitUntilFinished: false)
    }

    private func fetchAllMetaAccounts() {
        let metaAccountsOperation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainsOperation = fetchChainsOperation()

        metaAccountsOperation.addDependency(chainsOperation)

        metaAccountsOperation.completionBlock = { [weak self] in
            guard let metaAccountsResult = metaAccountsOperation.result else {
                self?.handle(.failure(WalletBalanceError.accountMissing))
                return
            }
            guard let chainsResult = chainsOperation.result else {
                self?.handle(.failure(WalletBalanceError.chainsMissing))
                return
            }

            switch (metaAccountsResult, chainsResult) {
            case let (.success(wallets), .success(chains)):
                let chainAssets = chains.map(\.chainAssets).reduce([], +)
                self?.handle(wallets, chainAssets)
            case let (.failure(error), _):
                self?.handle(.failure(error))
            case let (_, .failure(error)):
                self?.handle(.failure(error))
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

    private func subscribeToPrices(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId)
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func fetchChainsOperation() -> BaseOperation<[ChainModel]> {
        chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
    }

    private func handle(_ result: WalletBalancesResult) {
        dispatchInQueueWhenPossible(deliverQueue) { [weak self] in
            self?.delegate?.handle(result: result)
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

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +)

        updatedChainAssets.forEach { chainAsset in
            let key = chainAsset.chainAssetId
            self.chainAssets[key] = chainAsset
        }
        buildBalance()
    }

    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if let index = metaAccounts.firstIndex(where: { $0.metaId == event.account.metaId }) {
            metaAccounts[index] = event.account
        }

        switch subscriptionType {
        case .wallets:
            reset()
            fetchAllMetaAccounts()
        case let .wallet(walletId):
            reset()
            fetchMetaAccount(by: walletId, chainAsset: nil)
        case let .chainAsset(walletId, chainAsset):
            reset()
            fetchMetaAccount(by: walletId, chainAsset: chainAsset)
        case .none:
            break
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            lock.exclusivelyWrite {
                self.accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            }

            lock.concurrentlyRead {
                guard chainAssets.count == accountInfos.keys.count else {
                    if chainAssets.count == 1, chainAsset.chain.isEquilibrium {
                        buildBalance()
                    }
                    return
                }

                buildBalance()
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
            buildBalance()
        case let .failure(error):
            handle(.failure(error))
            logger.error("WalletBalanceFetcher error: \(error.localizedDescription)")
        }
    }
}
