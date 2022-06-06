import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import FearlessUtils

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    internal let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let rewardService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chainAsset: ChainAsset
    private let selectedAccount: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    private let eraValidatorService: EraValidatorServiceProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.eraValidatorService = eraValidatorService
        self.existentialDepositService = existentialDepositService
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
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        if let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        provideRewardCalculator()
        provideNetworkStakingInfo()

        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.presenter?.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }

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
                self?.presenter?.didReceive(accounts: accounts)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    ) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(
                amount: amount,
                controller: address,
                rewardDestination: rewardDestination.accountAddress
            )

            let targets = Array(
                repeating: SelectedValidatorInfo(address: address),
                count: SubstrateConstants.maxNominations
            )
            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceive(
                    paymentInfo: info,
                    for: amount,
                    rewardDestination: rewardDestination.accountAddress
                )
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
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            presenter?.didReceive(balance: accountInfo?.data)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

extension StakingAmountInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter?.didReceive(minBondAmount: value)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter?.didReceive(maxNominatorsCount: value)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter?.didReceive(counterForNominators: value)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}
