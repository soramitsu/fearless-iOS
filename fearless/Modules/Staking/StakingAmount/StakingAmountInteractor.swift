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
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let operationManager: OperationManagerProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let strategy: StakingAmountStrategy?

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

//    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
//    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
//    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        strategy: StakingAmountStrategy?
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.eraValidatorService = eraValidatorService
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

    func provideNetworkStakingInfo() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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
        provideNetworkStakingInfo()

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
        extrinsicService.estimateFee(extrinsicBuilderClosure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
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

// extension StakingAmountInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
//    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
//        switch result {
//        case let .success(value):
//            presenter?.didReceive(minBondAmount: value)
//        case let .failure(error):
//            presenter?.didReceive(error: error)
//        }
//    }
//
//    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
//        switch result {
//        case let .success(value):
//            presenter?.didReceive(maxNominatorsCount: value)
//        case let .failure(error):
//            presenter?.didReceive(error: error)
//        }
//    }
//
//    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
//        switch result {
//        case let .success(value):
//            presenter?.didReceive(counterForNominators: value)
//        case let .failure(error):
//            presenter?.didReceive(error: error)
//        }
//    }
// }
