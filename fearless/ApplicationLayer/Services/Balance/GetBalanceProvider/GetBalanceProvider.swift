import Foundation
import RobinHood
import SSFUtils
import SoraKeystore
import SSFModels

protocol GetBalanceMetaAccountHandler: AnyObject {
    func handleMetaAccountBalance(metaAccount: MetaAccountModel, balance: String?)
}

protocol GetBalanceManagedMetaAccountsHandler: AnyObject {
    func handleManagedMetaAccountsBalance(managedMetaAccounts: [ManagedMetaAccountModel])
}

protocol GetBalanceProviderProtocol {
    func getBalance(
        for metaAccount: MetaAccountModel,
        handler: GetBalanceMetaAccountHandler
    )

    func getBalances(
        for managedAccounts: [ManagedMetaAccountModel],
        handler: GetBalanceManagedMetaAccountsHandler
    )
}

enum GetBalanceModelType {
    case metaAccount
    case managedMetaAccounts
}

final class GetBalanceProvider: GetBalanceProviderProtocol {
    // MARK: - Deps

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let operationQueue: OperationQueue
    private let chainModelRepository: AnyDataProviderRepository<ChainModel>
    private lazy var balanceBuilder: BalanceBuilderProtocol = BalanceBuilder()

    // MARK: - Private properties

    private weak var metaAccountBalanceHandler: GetBalanceMetaAccountHandler?
    private weak var managedMetaAccountsBalanceHandler: GetBalanceManagedMetaAccountsHandler?

    // MARK: - State

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private lazy var chainModels: [ChainModel] = []
    private lazy var prices: [PriceData] = []

    private lazy var accountInfos: [ChainAssetKey: AccountInfo] = [:]
    private lazy var accountInfosAdapters: [String: AccountInfoSubscriptionAdapter] = [:]

    private let balanceForModel: GetBalanceModelType
    private var metaAccount: MetaAccountModel?
    private var managedMetaAccounts: [ManagedMetaAccountModel]?

    // MARK: - Constructor

    init(
        balanceForModel: GetBalanceModelType,
        chainModelRepository: AnyDataProviderRepository<ChainModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.balanceForModel = balanceForModel
        self.chainModelRepository = chainModelRepository
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }

    // MARK: - GetBalanceService

    func getBalance(
        for metaAccount: MetaAccountModel,
        handler: GetBalanceMetaAccountHandler
    ) {
        guard case .metaAccount = balanceForModel else {
            assertionFailure("GetBalanceProvider:calledWrongFunc")
            handleFailure()
            return
        }

        self.metaAccount = metaAccount
        metaAccountBalanceHandler = handler
        fetchChainsAndSubscribeBalance()
    }

    func getBalances(
        for managedAccounts: [ManagedMetaAccountModel],
        handler: GetBalanceManagedMetaAccountsHandler
    ) {
        guard case .managedMetaAccounts = balanceForModel else {
            assertionFailure("GetBalanceProvider:calledWrongFunc")
            handleFailure()
            return
        }

        managedMetaAccounts = managedAccounts
        managedMetaAccountsBalanceHandler = handler
        fetchChainsAndSubscribeBalance()
    }

    // MARK: - Private methods

    private func provideBalance() {
        switch balanceForModel {
        case .metaAccount:
            guard let metaAccountModel = metaAccount else {
                return
            }
            buildBalance(for: metaAccountModel)
        case .managedMetaAccounts:
            guard let managedMetaAccounts = managedMetaAccounts else {
                return
            }
            buildBalance(for: managedMetaAccounts)
        }
    }

    private func buildBalance(for metaAccount: MetaAccountModel) {
        guard
            !chainModels.isEmpty,
            !accountInfos.isEmpty,
            !prices.isEmpty
        else {
            return
        }

        balanceBuilder.buildBalance(
            chains: chainModels,
            accountInfos: accountInfos,
            prices: prices,
            metaAccount: metaAccount
        ) { [weak self] totalBalanceString in
            self?.metaAccountBalanceHandler?.handleMetaAccountBalance(
                metaAccount: metaAccount,
                balance: totalBalanceString
            )
        }
    }

    private func buildBalance(for managedMetaAccounts: [ManagedMetaAccountModel]) {
        guard
            !chainModels.isEmpty,
            !prices.isEmpty
        else {
            return
        }

        balanceBuilder.buildBalance(
            for: managedMetaAccounts,
            chains: chainModels,
            accountsInfos: accountInfos,
            prices: prices
        ) { [weak self] managedMetaAccounts in
            self?.managedMetaAccountsBalanceHandler?.handleManagedMetaAccountsBalance(
                managedMetaAccounts: managedMetaAccounts
            )
        }
    }

    private func handleFailure() {
        switch balanceForModel {
        case .metaAccount:
            guard let metaAccount = metaAccount else {
                return
            }
            metaAccountBalanceHandler?.handleMetaAccountBalance(
                metaAccount: metaAccount,
                balance: nil
            )
        case .managedMetaAccounts:
            guard let managedMetaAccounts = managedMetaAccounts else {
                return
            }
            managedMetaAccountsBalanceHandler?.handleManagedMetaAccountsBalance(
                managedMetaAccounts: managedMetaAccounts
            )
        }
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = chainModelRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            var filteredChains: [ChainModel]
            switch balanceForModel {
            case .metaAccount:
                guard let metaAccountModel = metaAccount else {
                    return
                }
                filteredChains = chains.filter {
                    metaAccountModel.fetch(for: $0.accountRequest()) != nil
                }
            case .managedMetaAccounts:
                guard let managedMetaAccounts = managedMetaAccounts else {
                    return
                }
                filteredChains = chains.filter { chain in
                    managedMetaAccounts.contains { managedMetaAccount in
                        managedMetaAccount.info.fetch(for: chain.accountRequest()) != nil
                    }
                }
            }

            chainModels = filteredChains
            subscribeToAccountInfo(chains: filteredChains)
            subscribeToPrices(for: filteredChains)

        case .failure, .none:
            handleFailure()
        }
    }

    private func subscribeToPrices(for chains: [ChainModel]) {
        let pricesIds = chains.compactMap { $0.chainAssets }.reduce([], +)
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func subscribeToAccountInfo(chains: [ChainModel]) {
        switch balanceForModel {
        case .metaAccount:
            guard let metaAccountModel = metaAccount else {
                return
            }
            let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: metaAccountModel
            )
            accountInfosAdapters[metaAccountModel.identifier] = accountInfoSubscriptionAdapter
            let chainsAssets = chains.map(\.chainAssets).reduce([], +)
            accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainsAssets, handler: self)

        case .managedMetaAccounts:
            guard let managedMetaAccounts = managedMetaAccounts else {
                return
            }
            managedMetaAccounts.forEach { managedMetaAccount in
                let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                    walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                    selectedMetaAccount: managedMetaAccount.info
                )
                accountInfosAdapters[managedMetaAccount.identifier] = accountInfoSubscriptionAdapter
                let chainsAssets = chains.map(\.chainAssets).reduce([], +)
                accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainsAssets, handler: self)
            }
        }
    }
}

extension GetBalanceProvider: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        switch result {
        case let .success(accountInfo):
            switch balanceForModel {
            case .metaAccount:
                accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            case .managedMetaAccounts:
                guard let accountInfo = accountInfo else {
                    return
                }

                accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            }
            provideBalance()
        case .failure:
            handleFailure()
        }
    }
}

extension GetBalanceProvider: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            self.prices = prices
        case .failure:
            handleFailure()
        }
        provideBalance()
    }
}
