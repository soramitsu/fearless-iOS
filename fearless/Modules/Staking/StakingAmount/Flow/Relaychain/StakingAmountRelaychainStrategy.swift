import Foundation
import BigInt
import RobinHood

protocol StakingAmountRelaychainStrategyOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(minimalBalance: BigUInt?)
    func didReceive(minimumBond: BigUInt?)
    func didReceive(counterForNominators: UInt32?)
    func didReceive(maxNominatorsCount: UInt32?)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
}

class StakingAmountRelaychainStrategy: RuntimeConstantFetching {
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let chain: ChainModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let extrinsicService: ExtrinsicServiceProtocol

    private weak var output: StakingAmountRelaychainStrategyOutput?

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        output: StakingAmountRelaychainStrategyOutput?
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.output = output
    }
}

extension StakingAmountRelaychainStrategy: StakingAmountStrategy {
    func setup() {
        minBondProvider = subscribeToMinNominatorBond(for: chain.chainId)

        counterForNominatorsProvider = subscribeToCounterForNominators(for: chain.chainId)

        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chain.chainId)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(amount):
                self?.output?.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            }
        }
    }

    func estimateFee(extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure) {
        extrinsicService.estimateFee(extrinsicBuilderClosure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.output?.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            }
        }
    }
}

extension StakingAmountRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            output?.didReceive(minimumBond: value)
        case let .failure(error):
            output?.didReceive(error: error)
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            output?.didReceive(maxNominatorsCount: value)
        case let .failure(error):
            output?.didReceive(error: error)
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            output?.didReceive(counterForNominators: value)
        case let .failure(error):
            output?.didReceive(error: error)
        }
    }
}
