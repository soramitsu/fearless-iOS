import Foundation
import RobinHood

protocol StakingBalanceParachainStrategyOutput: AnyObject {
    func didSetup()
    func didReceiveDelegation(_ delegation: ParachainStakingDelegation?)
    func didReceiveScheduledRequests(requests: [ParachainStakingScheduledRequest]?)
    func didReceiveCurrentRound(round: ParachainStakingRoundInfo?)
}

final class StakingBalanceParachainStrategy {
    private let collator: ParachainStakingCandidateInfo
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let operationFactory: ParachainCollatorOperationFactory
    private let operationManager: OperationManagerProtocol
    private weak var output: StakingBalanceParachainStrategyOutput?
    private let eventCenter: EventCenterProtocol

    init(
        collator: ParachainStakingCandidateInfo,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol,
        output: StakingBalanceParachainStrategyOutput?,
        eventCenter: EventCenterProtocol
    ) {
        self.collator = collator
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.output = output
        self.eventCenter = eventCenter
    }

    deinit {
        eventCenter.remove(observer: self)
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
        eventCenter.add(observer: self)

        output?.didSetup()

        fetchDelegations()
        fetchCurrentRound()
        fetchDelegationScheduledRequests()
    }
}

extension StakingBalanceParachainStrategy: EventVisitorProtocol {
    func processStakingUpdatedEvent() {
        fetchCurrentRound()
        fetchDelegationScheduledRequests()
    }
}
