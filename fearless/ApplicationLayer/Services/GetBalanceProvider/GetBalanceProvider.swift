import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore

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

    private var priceProviders: [AnySingleValueProvider<PriceData>]?
    private lazy var chainModels: [ChainModel] = []
    private lazy var prices: [AssetModel.PriceId: PriceData] = [:]

    private lazy var accountInfos: [ChainModel.Id: AccountInfo] = [:]
    private lazy var accountsInfoForAccountId: [String: [ChainModel.Id: AccountInfo]] = [:]

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
            !accountsInfoForAccountId.isEmpty,
            !prices.isEmpty
        else {
            return
        }

        balanceBuilder.buildBalance(
            chains: chainModels,
            accountInfos: accountInfos,
            prices: prices,
            currency: metaAccount.selectedCurrency
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
            accountsInfos: accountsInfoForAccountId,
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
        switch balanceForModel {
        case .metaAccount:
            guard let metaAccountModel = metaAccount else {
                return
            }
            let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: metaAccountModel
            )
            accountInfoSubscriptionAdapter.subscribe(chains: chains, handler: self)

        case .managedMetaAccounts:
            guard let managedMetaAccounts = managedMetaAccounts else {
                return
            }
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
        switch result {
        case let .success(accountInfo):
            switch balanceForModel {
            case .metaAccount:
                accountInfos[chainId] = accountInfo
            case .managedMetaAccounts:
                guard let accountInfo = accountInfo else {
                    return
                }

                let key = accountId.toHex() + chainId
                accountsInfoForAccountId[key] = [chainId: accountInfo]
                print("accountsInfoForAccountId: ", accountsInfoForAccountId.map(\.key))
            }
            provideBalance()
        case let .failure(error):
            print("GetBalanceProvider:handleAccountInfo:error", error)
        }
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
