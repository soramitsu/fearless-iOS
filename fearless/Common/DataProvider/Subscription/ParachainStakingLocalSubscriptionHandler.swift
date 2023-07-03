import Foundation
import SSFModels

protocol ParachainStakingLocalSubscriptionHandler {
    func handleCandidatePool(
        result: Result<ParachainStakingCandidate?, Error>,
        chainId: ChainModel.Id
    )
    func handleDelegatorState(
        result: Result<ParachainStakingDelegatorState?, Error>,
        chainAsset: ChainAsset,
        accountId: AccountId
    )
    func handleDelegationScheduledRequests(
        result: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainAsset: ChainAsset,
        accountId: AccountId
    )
}

extension ParachainStakingLocalSubscriptionHandler {
    func handleCandidatePool(
        result _: Result<ParachainStakingCandidate?, Error>,
        chainId _: ChainModel.Id
    ) {}
    func handleDelegatorState(
        result _: Result<ParachainStakingDelegatorState?, Error>,
        chainAsset _: ChainAsset,
        accountId _: AccountId
    ) {}
    func handleDelegationScheduledRequests(
        result _: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainAsset _: ChainAsset,
        accountId _: AccountId
    ) {}
}
