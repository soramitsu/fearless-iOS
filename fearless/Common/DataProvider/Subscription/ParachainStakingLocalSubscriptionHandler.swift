import Foundation

protocol ParachainStakingLocalSubscriptionHandler {
    func handleCandidatePool(result: Result<ParachainStakingCandidate?, Error>, chainId: ChainModel.Id)
}

extension ParachainStakingLocalSubscriptionHandler {
    func handleCandidatePool(result _: Result<ParachainStakingCandidate?, Error>, chainId _: ChainModel.Id) {}
}
