import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import FearlessUtils

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let operationManager: OperationManagerProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let strategy: StakingAmountStrategy?

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        strategy: StakingAmountStrategy?
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.strategy = strategy
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(calculator: engine)
                } catch {
                    self?.presenter?.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol, RuntimeConstantFetching,
    AccountFetching {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        if let accountId = selectedAccount.fetch(for: chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chain: chain, accountId: accountId, handler: self)
        }

        strategy?.setup()

        provideRewardCalculator()

        rewardService.setup()
    }

    func fetchAccounts() {
        fetchChainAccounts(
            chain: chain,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(accounts):
                self?.presenter?.didReceive(accounts: accounts)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func estimateFee(extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure) {
        strategy?.estimateFee(extrinsicBuilderClosure: extrinsicBuilderClosure)
    }
}

extension StakingAmountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

extension StakingAmountInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(accountInfo):
            presenter?.didReceive(balance: accountInfo?.data)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}
