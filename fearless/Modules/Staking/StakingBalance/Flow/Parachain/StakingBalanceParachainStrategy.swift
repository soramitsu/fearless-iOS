import Foundation
import RobinHood

protocol StakingBalanceParachainStrategyOutput: AnyObject {
    func didSetup()
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

    init(
        collator: ParachainStakingCandidateInfo,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol,
        output: StakingBalanceParachainStrategyOutput?
    ) {
        self.collator = collator
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.output = output
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
}

extension StakingBalanceParachainStrategy: StakingBalanceStrategy {
    func setup() {
        output?.didSetup()

        fetchCurrentRound()
        fetchDelegationScheduledRequests()
    }
}
