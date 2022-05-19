import Foundation
import RobinHood

protocol ParachainStakingLocalStorageSubscriber where Self: AnyObject {
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }

    var stakingLocalSubscriptionHandler: ParachainStakingLocalSubscriptionHandler { get }

    func subscribeToCandidatePool(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedParachainStakingCandidate>?
}

extension ParachainStakingLocalStorageSubscriber {
    func subscribeToCandidatePool(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedParachainStakingCandidate>? {
        guard let candidatePoolProvider = try? stakingLocalSubscriptionFactory.getCandidatePool(for: chainId) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedParachainStakingCandidate>]) in
            let candidatePool = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleCandidatePool(result: .success(candidatePool?.item), chainId: chainId)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleCandidatePool(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        candidatePoolProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return candidatePoolProvider
    }
}

extension ParachainStakingLocalStorageSubscriber where Self: ParachainStakingLocalSubscriptionHandler {
    var stakingLocalSubscriptionHandler: ParachainStakingLocalSubscriptionHandler { self }
}
