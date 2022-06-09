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
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError _: Error)
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
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol

    private weak var output: StakingAmountRelaychainStrategyOutput?

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        output: StakingAmountRelaychainStrategyOutput?,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.output = output
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.eraValidatorService = eraValidatorService
    }
}

extension StakingAmountRelaychainStrategy: StakingAmountStrategy {
    func setup() {
        eraValidatorService.setup()

        provideNetworkStakingInfo()

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

    func provideNetworkStakingInfo() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.output?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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
