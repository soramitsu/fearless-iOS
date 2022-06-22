import Foundation
import RobinHood

protocol StakingBalanceParachainStrategyOutput: AnyObject {
    func didSetup()
    func didReceiveDelegation(_ delegation: ParachainStakingDelegation?)
    func didReceiveScheduledRequests(requests: [ParachainStakingScheduledRequest]?)
    func didReceiveCurrentRound(round: ParachainStakingRoundInfo?)
}

final class StakingBalanceParachainStrategy {
    var delegatorStateProvider: AnyDataProvider<DecodedParachainDelegatorState>?
    var delegationScheduledRequestsProvider: AnyDataProvider<DecodedParachainScheduledRequests>?

    private let collator: ParachainStakingCandidateInfo
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let operationFactory: ParachainCollatorOperationFactory
    private let operationManager: OperationManagerProtocol
    private weak var output: StakingBalanceParachainStrategyOutput?
    var parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    private let logger: LoggerProtocol
    private let stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol

    deinit {
        stakingAccountUpdatingService.clearSubscription()
    }

    init(
        collator: ParachainStakingCandidateInfo,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol,
        output: StakingBalanceParachainStrategyOutput?,
        parachainStakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol,
        stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol
    ) {
        self.collator = collator
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.output = output
        self.parachainStakingLocalSubscriptionFactory = parachainStakingLocalSubscriptionFactory
        self.logger = logger
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
    }

    private func fetchDelegationScheduledRequests() {
        let delegationScheduledRequestsOperation = operationFactory.delegationScheduledRequests { [unowned self] in
            [self.collator.owner]
        }

        delegationScheduledRequestsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let requests = try? delegationScheduledRequestsOperation.targetOperation.extractNoCancellableResultData()
                self?.output?.didReceiveScheduledRequests(requests: requests)
            }
        }

        operationManager.enqueue(operations: delegationScheduledRequestsOperation.allOperations, in: .transient)
    }

    private func fetchCurrentRound() {
        let roundOperation = operationFactory.round()

        roundOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let round = try? roundOperation.targetOperation.extractNoCancellableResultData()
                self?.output?.didReceiveCurrentRound(round: round)
            }
        }

        operationManager.enqueue(operations: roundOperation.allOperations, in: .transient)
    }

    private func fetchDelegations() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
              let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let delegatorStateOperation = operationFactory.delegatorState {
            [accountId]
        }

        delegatorStateOperation.targetOperation.completionBlock = { [weak self] in
            let response = try? delegatorStateOperation.targetOperation.extractNoCancellableResultData()
            let delegatorState = response?[address]
            let delegation = delegatorState?.delegations.first(where: { $0.owner == self?.collator.owner })

            DispatchQueue.main.async {
                self?.output?.didReceiveDelegation(delegation)
            }
        }
        operationManager.enqueue(operations: delegatorStateOperation.allOperations, in: .transient)
    }
}

extension StakingBalanceParachainStrategy: StakingBalanceStrategy {
    func setup() {
        if let stakingType = chainAsset.stakingType {
            do {
                try stakingAccountUpdatingService.setupSubscription(
                    for: collator.owner,
                    chainId: chainAsset.chain.chainId,
                    chainFormat: chainAsset.chain.chainFormat,
                    stakingType: stakingType
                )
            } catch {
                logger.error("StakingBalanceParachainStrategy.stakingAccountUpdatingService.setupSubscription.error: \(error)")
            }
        }

        output?.didSetup()

        fetchDelegations()
        fetchCurrentRound()
        fetchDelegationScheduledRequests()

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            delegatorStateProvider = subscribeToDelegatorState(for: chainAsset.chain.chainId, accountId: accountId)
        }

        delegationScheduledRequestsProvider = subscribeToDelegationScheduledRequests(for: chainAsset.chain.chainId, accountId: collator.owner)
    }

    func refresh() {
        fetchDelegations()
        fetchCurrentRound()
        fetchDelegationScheduledRequests()
    }
}

extension StakingBalanceParachainStrategy: ParachainStakingLocalStorageSubscriber, ParachainStakingLocalSubscriptionHandler {
    func handleDelegatorState(
        result: Result<ParachainStakingDelegatorState?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        guard accountId == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId, chainAsset.chain.chainId == chainId else {
            return
        }
        switch result {
        case let .success(delegatorState):
            let delegation = delegatorState?.delegations.first(where: { $0.owner == collator.owner })
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveDelegation(delegation)
            }
        case let .failure(error):
            logger.error("StakingBalanceParachainStrategy.handleDelegatorState.error: \(error)")
        }
    }

    func handleDelegationScheduledRequests(
        result: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        guard accountId == collator.owner, chainAsset.chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(requests):
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveScheduledRequests(requests: requests)
            }
        case let .failure(error):
            logger.error("StakingBalanceParachainStrategy.handleDelegationScheduledRequests.error: \(error)")
        }
    }
}
