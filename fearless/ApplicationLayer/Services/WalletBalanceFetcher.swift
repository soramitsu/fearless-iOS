import Foundation
import RobinHood

// swiftlint:disable file_length
typealias WalletBalanceResult = Result<[String: WalletBalance], Error>
typealias WalletBalanceResultCompletion = (WalletBalanceResult) -> Void

protocol WalletBalanceFetcherProtocol {
    /// Collects and counts all the information for `WalletBalance`
    /// - Parameters:
    ///   - walletId: Balance for specific wallet Id. If nil calculating for all meta accounts
    ///   - completion: Called when WalletBalance will calculated
    ///   - queue: The queue to which the result will be delivered
    func fetchBalanceFor(
        walletId: String?,
        deliverOn queue: DispatchQueue?,
        completion: @escaping WalletBalanceResultCompletion
    )
}

enum WalletBalanceError: Error {
    case noData
    case `internal`
}

final class WalletBalanceFetcher: WalletBalanceFetcherProtocol, PriceLocalStorageSubscriber {
    // MARK: - PriceLocalStorageSubscriber

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private lazy var walletBalanceBuilder = WalletBalanceBuilder()
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let logger: Logger

    private var completion: WalletBalanceResultCompletion?
    private var deliverQueue: DispatchQueue?

    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]
    private lazy var accountInfos: [ChainAssetKey: AccountInfo] = [:]
    private lazy var chainAssets: [ChainAsset] = []
    private lazy var metaAccounts: [MetaAccountModel] = []
    private lazy var prices: [PriceData] = []

    // MARK: - Constructor

    init(
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        logger: Logger
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.metaAccountRepository = metaAccountRepository
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    // MARK: - Public methods

    func fetchBalanceFor(
        walletId: String?,
        deliverOn queue: DispatchQueue?,
        completion: @escaping WalletBalanceResultCompletion
    ) {
        self.completion = completion
        deliverQueue = queue

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
                accountInfos: self.accountInfos,
                metaAccounts: self.metaAccounts,
                chainAssets: self.chainAssets,
                prices: self.prices
            )

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

    private func fetchMetaAccount(by identifire: String) {
        let metaAccountOperation = metaAccountRepository.fetchOperation(
            by: identifire,
            options: RepositoryFetchOptions()
        )
        let chainsOperation = fetchChainsOperation()

        metaAccountOperation.addDependency(chainsOperation)

        metaAccountOperation.completionBlock = { [weak self] in
            guard
                let metaAccountResult = metaAccountOperation.result,
                let chainsResult = chainsOperation.result
            else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.noData))
                return
            }

            switch (metaAccountResult, chainsResult) {
            case let (.success(wallet), .success(chains)):
                guard let wallet = wallet else {
                    self?.deliverOnCompletion(.failure(WalletBalanceError.noData))
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
            guard
                let metaAccountsResult = metaAccountsOperation.result,
                let chainsResult = chainsOperation.result
            else {
                self?.deliverOnCompletion(.failure(WalletBalanceError.noData))
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

    private func deliverOnCompletion(_ result: WalletBalanceResult) {
        dispatchInQueueWhenPossible(deliverQueue) { [weak self] in
            self?.completion?(result)
        }
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension WalletBalanceFetcher: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountInfo = accountInfo else {
                return
            }
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

extension WalletBalanceFetcher: PriceLocalSubscriptionHandler {
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
        accountInfos: [ChainAssetKey: AccountInfo],
        metaAccounts: [MetaAccountModel],
        chainAssets: [ChainAsset],
        prices: [PriceData]
    ) -> [String: WalletBalance]
}

// MARK: - WalletBalanceBuilder

private final class WalletBalanceBuilder: WalletBalanceBuilderProtocol {
    func buildBalance(
        accountInfos: [ChainAssetKey: AccountInfo],
        metaAccounts: [MetaAccountModel],
        chainAssets: [ChainAsset],
        prices: [PriceData]
    ) -> [String: WalletBalance] {
        let walletBalanceMap = metaAccounts.reduce(
            [String: WalletBalance]()
        ) { (dict, account) -> [String: WalletBalance] in

            let splitedChainAssets = split(chainAssets: chainAssets, for: account)
            let enabledChainAssets = splitedChainAssets.enabled
            let disabledChainAssets = splitedChainAssets.disabled

            let enabledAssetFiatBalance = countBalance(
                for: enabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let disabledAssetFiatBalance = countBalance(
                for: disabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let totalFiatValue = enabledAssetFiatBalance + disabledAssetFiatBalance
            let dayChangePercent = countDayChangePercent(for: prices)
            let dayChangeValue = totalFiatValue * dayChangePercent / 100

            let walletBalance = WalletBalance(
                totalFiatValue: totalFiatValue,
                enabledAssetFiatBalance: enabledAssetFiatBalance,
                dayChangePercent: dayChangePercent,
                dayChangeValue: dayChangeValue,
                currency: account.selectedCurrency
            )

            var dict = dict
            dict[account.metaId] = walletBalance
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
        _ accountInfos: [ChainAssetKey: AccountInfo],
        _ prices: [PriceData]
    ) -> Decimal {
        let balance = chainAssets.map { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return .zero
            }
            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)]

            return getBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                prices: prices
            )
        }.reduce(Decimal.zero, +)

        return balance
    }

    private func split(
        chainAssets: [ChainAsset],
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

    private func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        prices: [PriceData]
    ) -> Decimal {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo: accountInfo
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
        accountInfo: AccountInfo?
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
