import Foundation
import Web3
import SSFModels

final class StakingBalanceParachainViewModelState: StakingBalanceViewModelState {
    var stateListener: StakingBalanceModelStateListener?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private(set) var collator: ParachainStakingCandidateInfo
    private(set) var delegation: ParachainStakingDelegation?
    private(set) var round: ParachainStakingRoundInfo?
    private(set) var requests: [ParachainStakingScheduledRequest]?
    private(set) var currentBlock: UInt32?
    private(set) var subqueryData: [DelegatorHistoryItem]?

    var rebondCases: [StakingRebondOption] {
        [.all]
    }

    var history: [ParachainStakingScheduledRequest]? {
        requests?.filter { ($0.whenExecutable > (round?.current) ?? 0) == true }
    }

    var bondMoreFlow: StakingBondMoreFlow? {
        .parachain(candidate: collator)
    }

    var unbondFlow: StakingUnbondSetupFlow? {
        guard let delegation = delegation else {
            return nil
        }

        return .parachain(candidate: collator, delegation: delegation)
    }

    var revokeFlow: StakingRedeemConfirmationFlow? {
        guard let delegation = delegation,
              let readyForRevoke = calculateRevokeAmount() else {
            return nil
        }

        return .parachain(
            collator: collator,
            delegation: delegation,
            readyForRevoke: readyForRevoke
        )
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        collator: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.collator = collator
        self.delegation = delegation
    }

    func decideRebondFlow(option _: StakingRebondOption) {
        guard let delegation = delegation, let request = requests?.last else {
            return
        }

        let delegationInfo = ParachainStakingDelegationInfo(
            delegation: delegation,
            collator: collator
        )

        stateListener?.decideShowConfirmRebondFlow(flow: .parachain(
            delegation: delegationInfo,
            request: request
        ))
    }

    func setStateListener(_ stateListener: StakingBalanceModelStateListener?) {
        self.stateListener = stateListener
    }

    func stakeMoreValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func stakeLessValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func revokeValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func unbondingMoreValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func calculateRevokeAmount() -> BigUInt? {
        let amount = requests?.filter { request in
            guard let currentEra = round?.current else {
                return false
            }

            return request.whenExecutable <= currentEra
        }.compactMap { request in
            var amount = BigUInt.zero
            if case let .revoke(revokeAmount) = request.action {
                amount += revokeAmount
            }

            if case let .decrease(decreaseAmount) = request.action {
                amount += decreaseAmount
            }

            return amount
        }.reduce(BigUInt.zero, +)

        return amount ?? BigUInt.zero
    }
}

extension StakingBalanceParachainViewModelState: StakingBalanceParachainStrategyOutput {
    func didReceiveSubqueryData(_ subqueryData: DelegatorHistoryResponse?) {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        self.subqueryData = subqueryData?.history(for: address)
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didSetup() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveScheduledRequests(requests: [ParachainStakingScheduledRequest]?) {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        self.requests = requests?.filter { $0.delegator == accountId } ?? []

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveCurrentRound(round: ParachainStakingRoundInfo?) {
        self.round = round

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveCurrentBlock(currentBlock: UInt32?) {
        self.currentBlock = currentBlock

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveDelegation(_ delegation: ParachainStakingDelegation?) {
        self.delegation = delegation

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
