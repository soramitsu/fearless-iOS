import Foundation
import RobinHood
import BigInt
import SSFModels

protocol StakingAmountParachainStrategyOutput: AnyObject {
    func didSetup()
    func didReceive(error: Error)
    func didReceive(minimalBalance: BigUInt?)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError _: Error)
}

class StakingAmountParachainStrategy: RuntimeConstantFetching {
    private var candidatePoolProvider: AnyDataProvider<DecodedParachainStakingCandidate>?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    private weak var output: StakingAmountParachainStrategyOutput?
    private let extrinsicService: ExtrinsicServiceProtocol
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        output: StakingAmountParachainStrategyOutput?,
        extrinsicService: ExtrinsicServiceProtocol,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.output = output
        self.extrinsicService = extrinsicService
        self.eraValidatorService = eraValidatorService
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.existentialDepositService = existentialDepositService
    }
}

extension StakingAmountParachainStrategy: StakingAmountStrategy {
    func setup() {
        output?.didSetup()

        eraValidatorService.setup()

        provideNetworkStakingInfo()

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
