import Foundation
import BigInt

final class StakingBalanceParachainViewModelState: StakingBalanceViewModelState {
    var stateListener: StakingBalanceModelStateListener?

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

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private(set) var collator: ParachainStakingCandidateInfo
    private(set) var delegation: ParachainStakingDelegation

    var requests: [ParachainStakingScheduledRequest]?
    var round: ParachainStakingRoundInfo?

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

    var bondMoreFlow: StakingBondMoreFlow? {
        .parachain(candidate: collator)
    }

    var unbondFlow: StakingUnbondSetupFlow? {
        .parachain(candidate: collator, delegation: delegation)
    }

    var revokeFlow: StakingRedeemFlow? {
        guard let readyForRevoke = calculateRevokeAmount() else {
            return nil
        }

        return .parachain(
            collator: collator,
            delegation: delegation,
            readyForRevoke: readyForRevoke
        )
    }

    func calculateRevokeAmount() -> BigUInt? {
        let revokeRequests = requests?.filter { request in
            if case .revoke = request.action {
                return true
            }

            return false
        }

        let amount = revokeRequests?.filter { request in
            guard let currentEra = round?.current else {
                return false
            }

            return request.whenExecutable < currentEra
        }.compactMap { request in
            var amount = BigUInt.zero
            if case let .revoke(revokeAmount) = request.action {
                amount = revokeAmount
            }

            return amount
        }.reduce(BigUInt.zero, +)

        return amount
    }
}

extension StakingBalanceParachainViewModelState: StakingBalanceParachainStrategyOutput {
    func didSetup() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveScheduledRequests(requests: [ParachainStakingScheduledRequest]?) {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        self.requests = requests

//        self.requests = requests?.filter { $0.delegator == accountId }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveCurrentRound(round: ParachainStakingRoundInfo?) {
        self.round = round

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
