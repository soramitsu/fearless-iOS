import Foundation
import RobinHood
import SSFModels

protocol ParachainStakingLocalStorageSubscriber where Self: AnyObject {
    var parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }
    var parachainStakingLocalSubscriptionHandler: ParachainStakingLocalSubscriptionHandler { get }

    func subscribeToCandidatePool(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedParachainStakingCandidate>?

    func subscribeToDelegatorState(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedParachainDelegatorState>?

    func subscribeToDelegationScheduledRequests(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedParachainScheduledRequests>?
}

extension ParachainStakingLocalStorageSubscriber {
    func subscribeToDelegationScheduledRequests(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedParachainScheduledRequests>? {
        guard let delegationScheduledRequestsProvider = try? parachainStakingLocalSubscriptionFactory
            .getDelegationScheduledRequests(
                chainAsset: chainAsset,
                accountId: accountId
            )
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedParachainScheduledRequests>]) in
            let delegationScheduledRequests = changes.reduceToLastChange()
            self?.parachainStakingLocalSubscriptionHandler.handleDelegationScheduledRequests(
                result: .success(delegationScheduledRequests?.item),
                chainAsset: chainAsset,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parachainStakingLocalSubscriptionHandler.handleDelegationScheduledRequests(
                result: .failure(error),
                chainAsset: chainAsset,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        delegationScheduledRequestsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return delegationScheduledRequestsProvider
    }

    func subscribeToDelegatorState(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedParachainDelegatorState>? {
        guard let delegatorStateProvider = try? parachainStakingLocalSubscriptionFactory.getDelegatorState(
            chainAsset: chainAsset,
            accountId: accountId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedParachainDelegatorState>]) in
            let delegatorState = changes.reduceToLastChange()
            self?.parachainStakingLocalSubscriptionHandler.handleDelegatorState(
                result: .success(delegatorState?.item),
                chainAsset: chainAsset,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parachainStakingLocalSubscriptionHandler.handleDelegatorState(
                result: .failure(error),
                chainAsset: chainAsset,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        delegatorStateProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return delegatorStateProvider
    }

    func subscribeToCandidatePool(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedParachainStakingCandidate>? {
        guard let candidatePoolProvider = try? parachainStakingLocalSubscriptionFactory
            .getCandidatePool(for: chainId)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedParachainStakingCandidate>]) in
            let candidatePool = changes.reduceToLastChange()
            self?.parachainStakingLocalSubscriptionHandler.handleCandidatePool(
                result: .success(candidatePool?.item),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.parachainStakingLocalSubscriptionHandler.handleCandidatePool(
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
    var parachainStakingLocalSubscriptionHandler: ParachainStakingLocalSubscriptionHandler { self }
}
