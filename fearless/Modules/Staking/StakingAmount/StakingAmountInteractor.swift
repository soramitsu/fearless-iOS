import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import SSFUtils
import SSFModels

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let rewardService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let strategy: StakingAmountStrategy?

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        strategy: StakingAmountStrategy?
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.wallet = wallet
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
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        strategy?.setup()

        provideRewardCalculator()

        rewardService.setup()
    }

    func fetchAccounts() {
        fetchChainAccounts(
            chain: chainAsset.chain,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(accounts):
                self?.presenter?.didReceive(accounts: accounts.filter { $0.isChainAccount == false })
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
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            presenter?.didReceive(balance: accountInfo?.data)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}
