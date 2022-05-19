import Foundation
import RobinHood

protocol StakingAmountParachainStrategyOutput: AnyObject {
    func didReceive(paymentInfo: RuntimeDispatchInfo)
}

class StakingAmountParachainStrategy {
    private var candidatePoolProvider: AnyDataProvider<DecodedParachainStakingCandidate>?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    private weak var output: StakingAmountParachainStrategyOutput?

    init(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        output: StakingAmountParachainStrategyOutput?
    ) {
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.output = output
    }
}

extension StakingAmountParachainStrategy: StakingAmountStrategy {
    func setup() {}

    func estimateFee(extrinsicBuilderClosure _: @escaping ExtrinsicBuilderClosure) {
        output?.didReceive(paymentInfo: RuntimeDispatchInfo(
            dispatchClass: "class",
            fee: "100",
            weight: 100
        ))
    }
}

extension StakingAmountParachainStrategy: ParachainStakingLocalStorageSubscriber, ParachainStakingLocalSubscriptionHandler {}
