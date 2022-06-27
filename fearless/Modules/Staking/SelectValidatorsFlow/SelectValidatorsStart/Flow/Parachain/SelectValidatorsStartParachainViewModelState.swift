import Foundation

class SelectValidatorsStartParachainViewModelState: SelectValidatorsStartViewModelState {
    let bonding: InitiatedBonding
    let chainAsset: ChainAsset

    init(bonding: InitiatedBonding, chainAsset: ChainAsset) {
        self.bonding = bonding
        self.chainAsset = chainAsset
    }

    var maxDelegations: Int?
    var maxTopDelegationsPerCandidate: Int?
    var maxBottomDelegationsPerCandidate: Int?

    private(set) var collatorsApr: [SubqueryCollatorData]?
    var selectedCandidates: [ParachainStakingCandidateInfo]?
    var recommendedCandidates: [ParachainStakingCandidateInfo]?
    private var topDelegationsByCollator: [AccountAddress: ParachainStakingDelegations] = [:]
    private var bottomDelegationsByCollator: [AccountAddress: ParachainStakingDelegations] = [:]

    var stateListener: SelectValidatorsStartModelStateListener?

    func setStateListener(_ stateListener: SelectValidatorsStartModelStateListener?) {
        self.stateListener = stateListener
    }

    var customValidatorListFlow: CustomValidatorListFlow? {
        guard let selectedCandidates = selectedCandidates, let maxDelegations = maxDelegations else {
            return nil
        }

        return .parachain(
            candidates: selectedCandidates,
            maxTargets: maxDelegations,
            bonding: bonding,
            selectedValidatorList: SharedList(items: [])
        )
    }

    var recommendedValidatorListFlow: RecommendedValidatorListFlow? {
        guard let maxDelegations = maxDelegations,
              let recommendedCandidates = recommendedCandidates else {
            return nil
        }

        return .parachain(collators: recommendedCandidates, maxTargets: maxDelegations, bonding: bonding)
    }

    private func updateRecommendedCollators() {
        guard topDelegationsByCollator.count == selectedCandidates?.count,
              let selectedCandidates = selectedCandidates else {
            return
        }

        recommendedCandidates = []

        for candidate in selectedCandidates {
            if let delegations = topDelegationsByCollator[candidate.address] {
                if let minimumDelegation = delegations.delegations.map(\.amount).min(),
                   let minimumDelegationDecimal = Decimal.fromSubstrateAmount(minimumDelegation, precision: Int16(chainAsset.asset.precision)) {
                    if bonding.amount > minimumDelegationDecimal {
                        recommendedCandidates?.append(candidate)
                    }
                }
            }
        }
    }
}

extension SelectValidatorsStartParachainViewModelState: SelectValidatorsStartParachainStrategyOutput {
    
    func didReceiveBottomDelegations(delegations: [AccountAddress : ParachainStakingDelegations]) {
        bottomDelegationsByCollator = delegations
    }
    
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations]) {
        topDelegationsByCollator = delegations

        updateRecommendedCollators()
    }

    func didReceiveMaxDelegations(result: Result<Int, Error>) {
        switch result {
        case let .success(maxDelegations):
            self.maxDelegations = maxDelegations

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveSelectedCandidates(selectedCandidates: [ParachainStakingCandidateInfo]) {
        self.selectedCandidates = selectedCandidates

        updateRecommendedCollators()

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveMaxTopDelegationsPerCandidate(result: Result<Int, Error>) {
        switch result {
        case let .success(maxTopDelegationsPerCandidate):
            self.maxTopDelegationsPerCandidate = maxTopDelegationsPerCandidate

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMaxBottomDelegationsPerCandidate(result: Result<Int, Error>) {
        switch result {
        case let .success(maxBottomDelegationsPerCandidate):
            self.maxBottomDelegationsPerCandidate = maxBottomDelegationsPerCandidate

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveCollatorsApr(collatorsApr: [SubqueryCollatorData]) {
        self.collatorsApr = collatorsApr

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
