import Foundation
import RobinHood

// swiftlint:disable file_length
typealias WalletBalancesResult = Result<[MetaAccountId: WalletBalance], Error>

protocol WalletBalanceFetcherHandler: AnyObject {
    func handle(result: WalletBalancesResult)
}

protocol WalletBalanceSubscriptionAdapterProtocol {
    /// Collects and counts all the information for `WalletBalance`
    /// - Parameters:
    ///   - walletId: Balance for specific wallet Id. If nil calculating for all meta accounts
    ///   - completion: Called when WalletBalance will calculated
    ///   - queue: The queue to which the result will be delivered
    func subsctibeWalletBalance(
        walletId: String?,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceFetcherHandler
    )
}

enum WalletBalanceError: Error {
    case accountMissing
    case chainsMissing
    case `internal`
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
    private weak var delegate: WalletBalanceFetcherHandler?

    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private lazy var chainAssets: [ChainAsset] = []
    private lazy var metaAccounts: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []

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
        eventCenter.add(observer: self, dispatchIn: .global())
    }

    // MARK: - Public methods

    func subsctibeWalletBalance(
        walletId: String?,
        deliverOn queue: DispatchQueue?,
        handler: WalletBalanceFetcherHandler
    ) {
        deliverQueue = queue
        delegate = handler

        if let identifier = walletId {
            fetchMetaAccount(by: identifier)
        } else {
            fetchAllMetaAccounts()
        }
    }

    // MARK: - Private methods

    private func buildBalance() {
        guard
            accountInfos.isNotEmpty,
            prices.isNotEmpty
        else {
            return
        }

        let builderBlock = BlockOperation {
            let walletBalances = self.walletBalanceBuilder.buildBalance(
                for: self.accountInfos,
                self.metaAccounts,
                self.chainAssets,
                self.prices
            )

            guard let walletBalances = walletBalances else {
                return
            }

            self.deliverOnCompletion(.success(walletBalances))
        }

        operationQueue.addOperation(builderBlock)
    }

    private func handle(_ wallets: [MetaAccountModel], _ chains: [ChainModel]) {
        let chainsAssets = chains.map(\.chainAssets).reduce([], +)
        chainAssets = chainsAssets
        metaAccounts = wallets

        subscribeToAccountInfo(for: wallets, chainsAssets)
        subscribeToPrices(for: chains)
    }

    private func fetchMetaAccount(by identifier: String) {
        let metaAccountOperation = metaAccountRepository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )
        let chainsOperation = fetchChainsOperation()

        metaAccountOperation.addDependency(chainsOperation)

        metaAccountOperation.completionBlock = { [weak self] in
            guard let metaAccountResult = metaAccountOperation.result else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.accountMissing))
                return
            }
            guard let chainsResult = chainsOperation.result else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.chainsMissing))
                return
            }

            switch (metaAccountResult, chainsResult) {
            case let (.success(wallet), .success(chains)):
                guard let wallet = wallet else {
                    self?.deliverOnCompletion(.failure(WalletBalanceError.accountMissing))
                    return
                }
                self?.handle([wallet], chains)
            case let (.failure(error), _):
                self?.deliverOnCompletion(.failure(error))
            case let (_, .failure(error)):
                self?.deliverOnCompletion(.failure(error))
            }
        }

        operationQueue.addOperations([chainsOperation, metaAccountOperation], waitUntilFinished: false)
    }

    private func fetchAllMetaAccounts() {
        let metaAccountsOperation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainsOperation = fetchChainsOperation()

        metaAccountsOperation.addDependency(chainsOperation)

        metaAccountsOperation.completionBlock = { [weak self] in
            guard let metaAccountsResult = metaAccountsOperation.result else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.accountMissing))
                return
            }
            guard let chainsResult = chainsOperation.result else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.chainsMissing))
                return
            }

            switch (metaAccountsResult, chainsResult) {
            case let (.success(wallets), .success(chains)):
                self?.handle(wallets, chains)
            case let (.failure(error), _):
                self?.deliverOnCompletion(.failure(error))
            case let (_, .failure(error)):
                self?.deliverOnCompletion(.failure(error))
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

            accountInfosAdapters[wallet.identifier] = accountInfoSubscriptionAdapter
            accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)
        }
    }

    private func subscribeToPrices(for chains: [ChainModel]) {
        let pricesIds = chains.compactMap { $0.assets.compactMap(\.asset.priceId) }.reduce([], +)
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func fetchChainsOperation() -> BaseOperation<[ChainModel]> {
        chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
    }

    private func deliverOnCompletion(_ result: WalletBalancesResult) {
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
        buildBalance()
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +)
        for (index, chainAsset) in chainAssets.enumerated() {
            updatedChainAssets.forEach { updatedChainAsset in
                if chainAsset.chainAssetId == updatedChainAsset.chainAssetId {
                    chainAssets[index] = updatedChainAsset
                }
            }
        }
        buildBalance()
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        buildBalance()
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceSubscriptionAdapter: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            buildBalance()
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
        case let .failure(error):
            deliverOnCompletion(.failure(error))
            logger.error("WalletBalanceFetcher error: \(error.localizedDescription)")
        }
        buildBalance()
    }
}

// MARK: - WalletBalanceBuilderProtocol

private protocol WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalance]?
}

// MARK: - WalletBalanceBuilder

private final class WalletBalanceBuilder: WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalance]? {
        let walletBalanceMap = metaAccounts.reduce(
            [MetaAccountId: WalletBalance]()
        ) { (dict, account) -> [MetaAccountId: WalletBalance]? in

            let splitedChainAssets = split(chainAssets, for: account)
            let enabledChainAssets = splitedChainAssets.enabled
            let disabledChainAssets = splitedChainAssets.disabled

            let enabledAssetFiatBalanceInfo = countBalance(
                for: enabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let disabledAssetFiatBalanceInfo = countBalance(
                for: disabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let enabledAssetFiatBalance = enabledAssetFiatBalanceInfo.totalBalance
            let disabledAssetFiatBalance = disabledAssetFiatBalanceInfo.totalBalance
            let totalFiatValue = enabledAssetFiatBalance + disabledAssetFiatBalance
            let dayChangePercent = countDayChangePercent(for: prices)
            let dayChangeValue = totalFiatValue * dayChangePercent / 100
            let isLoaded = enabledAssetFiatBalanceInfo.isLoaded && disabledAssetFiatBalanceInfo.isLoaded

            guard isLoaded else {
                return nil
            }

            let walletBalance = WalletBalance(
                totalFiatValue: totalFiatValue,
                enabledAssetFiatBalance: enabledAssetFiatBalance,
                dayChangePercent: dayChangePercent,
                dayChangeValue: dayChangeValue,
                currency: account.selectedCurrency
            )

            var dict = dict
            dict?[account.metaId] = walletBalance
            return dict
        }

        return walletBalanceMap
    }

    private func countDayChangePercent(for prices: [PriceData]) -> Decimal {
        let fiatDayChanges = prices.compactMap { priceData in
            priceData.fiatDayChange
        }

        let dayChange = fiatDayChanges.reduce(Decimal.zero, +)
        let dayChangePercent = dayChange / Decimal(fiatDayChanges.count)

        return dayChangePercent
    }

    private func countBalance(
        for chainAssets: [ChainAsset],
        _ metaAccount: MetaAccountModel,
        _ accountInfos: [ChainAssetKey: AccountInfo?],
        _ prices: [PriceData]
    ) -> CountBalanceInfo {
        var accountInfosCount = 0

        let balance = chainAssets.map { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return .zero
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            let accountInfo = accountInfos[chainAssetKey] ?? nil

            let balance = getFiatBalance(
                for: chainAsset,
                accountInfo,
                prices
            )

            if accountInfos.keys.contains(chainAssetKey) {
                accountInfosCount += 1
            }

            return balance
        }.reduce(Decimal.zero, +)

        let isLoaded = accountInfosCount == chainAssets.count
        return CountBalanceInfo(
            totalBalance: balance,
            isLoaded: isLoaded
        )
    }

    private struct CountBalanceInfo {
        let totalBalance: Decimal
        let isLoaded: Bool
    }

    private func split(
        _ chainAssets: [ChainAsset],
        for metaAccount: MetaAccountModel
    ) -> (enabled: [ChainAsset], disabled: [ChainAsset]) {
        var enabledChainAssets: [ChainAsset] = []
        var disabledChainAssets: [ChainAsset] = []

        chainAssets.forEach { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

            if
                let assetIdsEnabled = metaAccount.assetIdsEnabled,
                assetIdsEnabled.contains(chainAssetKey) {
                enabledChainAssets.append(chainAsset)
            } else {
                disabledChainAssets.append(chainAsset)
            }
        }

        return (enabled: enabledChainAssets, disabled: disabledChainAssets)
    }

    private func getFiatBalance(
        for chainAsset: ChainAsset,
        _ accountInfo: AccountInfo?,
        _ prices: [PriceData]
    ) -> Decimal {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo
        )

        guard let priceId = chainAsset.asset.priceId,
              let priceData = prices.first(where: { $0.priceId == priceId }),
              let priceDecimal = Decimal(string: priceData.price)
        else {
            return .zero
        }

        return priceDecimal * balanceDecimal
    }

    private func getBalance(
        for chainAsset: ChainAsset,
        _ accountInfo: AccountInfo?
    ) -> Decimal {
        guard
            let accountInfo = accountInfo,
            let balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: chainAsset.asset.displayInfo.assetPrecision
            )
        else {
            return .zero
        }

        return balance
    }
}
