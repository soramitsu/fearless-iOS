import Foundation
import RobinHood
import FearlessUtils

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

final class GetBalanceProvider: GetBalanceProviderProtocol {
    private enum GetBalanceModelType {
        case metaAccount(MetaAccountModel)
        case managedMetaAccounts([ManagedMetaAccountModel])
    }

    // MARK: - Deps

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let operationQueue: OperationQueue
    private let chainModelRepository: AnyDataProviderRepository<ChainModel>
    private lazy var balanceBuilder: BalanceBuilderProtocol = BalanceBuilder()

    // MARK: - Private properties

    private weak var metaAccountBalanceHandler: GetBalanceMetaAccountHandler?
    private weak var managedMetaAccountsBalanceHandler: GetBalanceManagedMetaAccountsHandler?

    // MARK: - State

    private var priceProviders: [AnySingleValueProvider<PriceData>]?
    private lazy var chainModels: [ChainModel] = []
    private lazy var prices: [AssetModel.PriceId: PriceData] = [:]

    private lazy var metaAccountInfos: [ChainModel.Id: AccountInfo] = [:]
    private lazy var managedMetaAccountsInfo: [AccountId: [ChainModel.Id: AccountInfo]] = [:]

    private var balanceForModel: GetBalanceModelType?

    // MARK: - Constructor

    init(
        chainModelRepository: AnyDataProviderRepository<ChainModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainModelRepository = chainModelRepository
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }

    // MARK: - GetBalanceService

    func getBalance(
        for metaAccount: MetaAccountModel,
        handler: GetBalanceMetaAccountHandler
    ) {
        balanceForModel = .metaAccount(metaAccount)
        metaAccountBalanceHandler = handler
        fetchChainsAndSubscribeBalance()
    }

    func getBalances(
        for managedAccounts: [ManagedMetaAccountModel],
        handler: GetBalanceManagedMetaAccountsHandler
    ) {
        balanceForModel = .managedMetaAccounts(managedAccounts)
        managedMetaAccountsBalanceHandler = handler
        fetchChainsAndSubscribeBalance()
    }

    // MARK: - Private methods

    private func provideBalance() {
        guard let balanceForModel = balanceForModel else {
            return
        }
        switch balanceForModel {
        case let .metaAccount(metaAccountModel):
            buildBalance(for: metaAccountModel)
        case let .managedMetaAccounts(managedMetaAccounts):
            buildBalance(for: managedMetaAccounts)
        }
    }

    private func buildBalance(for metaAccount: MetaAccountModel) {
        guard
            !chainModels.isEmpty,
            !metaAccountInfos.isEmpty,
            !prices.isEmpty
        else {
            return
        }

        balanceBuilder.buildBalance(
            chains: chainModels,
            accountInfos: metaAccountInfos,
            prices: prices
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
            !prices.isEmpty,
            managedMetaAccountsInfo.keys.count == managedMetaAccounts.count
        else {
            return
        }

        balanceBuilder.buildBalance(
            for: managedMetaAccounts,
            chains: chainModels,
            accountsInfos: managedMetaAccountsInfo,
            prices: prices
        ) { [weak self] managedMetaAccounts in
            self?.managedMetaAccountsBalanceHandler?.handleManagedMetaAccountsBalance(
                managedMetaAccounts: managedMetaAccounts
            )
        }
    }

    private func handleFailure() {
        guard let balanceForModel = balanceForModel else {
            return
        }
        switch balanceForModel {
        case let .metaAccount(metaAccount):
            metaAccountBalanceHandler?.handleMetaAccountBalance(
                metaAccount: metaAccount,
                balance: nil
            )
        case let .managedMetaAccounts(managedMetaAccounts):
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
            let accountSupportsEthereum = SelectedWalletSettings.shared.value?.ethereumPublicKey != nil

            let filteredChains: [ChainModel] = accountSupportsEthereum
                ? chains
                : chains.filter { $0.isEthereumBased == false }

            chainModels = filteredChains
            subscribeToAccountInfo(chains: filteredChains)
            subscribeToPrice(for: filteredChains)

        case .failure, .none:
            handleFailure()
        }
    }

    private func subscribeToPrice(for chains: [ChainModel]) {
        var providers: [AnySingleValueProvider<PriceData>] = []

        for chain in chains {
            for asset in chain.assets {
                if
                    let priceId = asset.asset.priceId,
                    let dataProvider = subscribeToPrice(for: priceId) {
                    providers.append(dataProvider)
                }
            }
        }

        priceProviders = providers
    }

    private func subscribeToAccountInfo(chains: [ChainModel]) {
        guard let balanceForModel = balanceForModel else {
            return
        }
        switch balanceForModel {
        case let .metaAccount(metaAccountModel):
            let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: metaAccountModel
            )
            accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)

        case let .managedMetaAccounts(managedMetaAccounts):
            managedMetaAccounts.forEach { managedMetaAccount in
                let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                    walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                    selectedMetaAccount: managedMetaAccount.info
                )
                accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)
            }
        }
    }
}

extension GetBalanceProvider: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) {
        guard let balanceForModel = balanceForModel else {
            return
        }
        switch balanceForModel {
        case .metaAccount:
            metaAccountInfos[chainId] = try? result.get()
        case .managedMetaAccounts:
            guard let accountInfo = try? result.get() else { return }
            managedMetaAccountsInfo[accountId] = [chainId: accountInfo]
        }
        provideBalance()
    }
}

extension GetBalanceProvider: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if prices[priceId] != nil, case let .success(priceData) = result, priceData != nil {
            prices[priceId] = try? result.get()
        } else if prices[priceId] == nil {
            prices[priceId] = try? result.get()
        }

        provideBalance()
    }
}
