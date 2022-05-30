import Foundation
import RobinHood

protocol StakingAmountParachainStrategyOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
}

class StakingAmountParachainStrategy {
    private var candidatePoolProvider: AnyDataProvider<DecodedParachainStakingCandidate>?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    private weak var output: StakingAmountParachainStrategyOutput?
    private let extrinsicService: ExtrinsicServiceProtocol

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        output: StakingAmountParachainStrategyOutput?,
        extrinsicService: ExtrinsicServiceProtocol
    ) {
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.output = output
        self.extrinsicService = extrinsicService
    }
}

extension StakingAmountParachainStrategy: StakingAmountStrategy {
    func setup() {}

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

extension StakingAmountParachainStrategy: ParachainStakingLocalStorageSubscriber, ParachainStakingLocalSubscriptionHandler {}
