import Foundation

protocol ParachainStakingLocalSubscriptionHandler {
    func handleCandidatePool(
        result: Result<ParachainStakingCandidate?, Error>,
        chainId: ChainModel.Id
    )
    func handleDelegatorState(
        result: Result<ParachainStakingDelegatorState?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )
    func handleDelegationScheduledRequests(
        result: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainId: ChainModel.Id,
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
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}
    func handleDelegationScheduledRequests(
        result _: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}
}
