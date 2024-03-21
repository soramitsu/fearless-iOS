import Foundation
import BigInt
import RobinHood
import SSFModels

protocol StakingAmountRelaychainStrategyOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(minimalBalance: BigUInt?)
    func didReceive(minimumBond: BigUInt?)
    func didReceive(counterForNominators: UInt32?)
    func didReceive(maxNominatorsCount: UInt32?)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError _: Error)
    func didReceive(maxNominations: Int)
    func didReceive(rewardAssetPrice: PriceData?)
}

class StakingAmountRelaychainStrategy: RuntimeConstantFetching {
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let chainAsset: ChainAsset
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol
    private let rewardChainAsset: ChainAsset?

    private weak var output: StakingAmountRelaychainStrategyOutput?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        output: StakingAmountRelaychainStrategyOutput?,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol,
        rewardChainAsset: ChainAsset?,
        priceLocalSubscriber: PriceLocalStorageSubscriber
    ) {
        self.chainAsset = chainAsset
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.output = output
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.eraValidatorService = eraValidatorService
        self.existentialDepositService = existentialDepositService
        self.rewardChainAsset = rewardChainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
    }

    private func fetchMaxNominations() {
        fetchConstant(
            for: .maxNominations,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Int, Error>) in
            switch result {
            case let .success(value):
                self?.output?.didReceive(maxNominations: value)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            }
        }
    }
}

extension StakingAmountRelaychainStrategy: StakingAmountStrategy {
    func setup() {
        fetchMaxNominations()
        eraValidatorService.setup()
        provideNetworkStakingInfo()

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.output?.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            }
        }

        if let chainAsset = rewardChainAsset {
            priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
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

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
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

extension StakingAmountRelaychainStrategy: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        switch result {
        case let .success(priceData):
            output?.didReceive(rewardAssetPrice: priceData)
        case let .failure(error):
            output?.didReceive(error: error)
        }
    }
}
