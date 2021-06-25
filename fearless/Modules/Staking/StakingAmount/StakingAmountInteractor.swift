import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import FearlessUtils

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let repository: AnyDataProviderRepository<AccountItem>
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let operationManager: OperationManagerProtocol
    let assetId: WalletAssetId
    let chain: Chain
    let accountAddress: AccountAddress

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?

    init(
        accountAddress: AccountAddress,
        repository: AnyDataProviderRepository<AccountItem>,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.repository = repository
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicService = extrinsicService
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.assetId = assetId
        self.accountAddress = accountAddress
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
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
        priceProvider = subscribeToPriceProvider(for: assetId)
        balanceProvider = subscribeToAccountInfoProvider(for: accountAddress, runtimeService: runtimeService)
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)
        minBondProvider = subscribeToMinNominatorBondProvider(chain: chain, runtimeService: runtimeService)

        counterForNominatorsProvider = subscribeToCounterForNominatorsProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        maxNominatorsCountProvider = subscribeToMaxNominatorsCountProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        provideRewardCalculator()

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(amount):
                self?.presenter.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func fetchAccounts() {
        fetchAllAccounts(from: repository, operationManager: operationManager) { [weak self] result in
            switch result {
            case let .success(accounts):
                self?.presenter.didReceive(accounts: accounts)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<AccountItem>
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
                self?.presenter.didReceive(
                    paymentInfo: info,
                    for: amount,
                    rewardDestination: rewardDestination
                )
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}

extension StakingAmountInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(price: priceData)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        switch result {
        case let .success(accountInfo):
            presenter.didReceive(balance: accountInfo?.data)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chain _: Chain) {
        switch result {
        case let .success(value):
            presenter.didReceive(minBondAmount: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chain _: Chain) {
        switch result {
        case let .success(value):
            presenter.didReceive(counterForNominators: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chain _: Chain) {
        switch result {
        case let .success(value):
            presenter.didReceive(maxNominatorsCount: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        switch result {
        case let .success(status):
            presenter.didReceive(electionStatus: status)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}
