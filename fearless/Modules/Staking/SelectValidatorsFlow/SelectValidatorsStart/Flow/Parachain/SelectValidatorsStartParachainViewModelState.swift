import Foundation

final class SelectValidatorsStartParachainViewModelState: SelectValidatorsStartViewModelState {
    let bonding: InitiatedBonding
    let chainAsset: ChainAsset
    private(set) var maxDelegations: Int?
    private(set) var maxTopDelegationsPerCandidate: Int?
    private(set) var maxBottomDelegationsPerCandidate: Int?
    private(set) var collatorsApr: [CollatorAprInfoProtocol]?
    private(set) var selectedCandidates: [ParachainStakingCandidateInfo]?
    private(set) var recommendedCandidates: [ParachainStakingCandidateInfo]?
    private var topDelegationsByCollator: [AccountAddress: ParachainStakingDelegations] = [:]
    var stateListener: SelectValidatorsStartModelStateListener?

    init(bonding: InitiatedBonding, chainAsset: ChainAsset) {
        self.bonding = bonding
        self.chainAsset = chainAsset
    }

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

    func recommendedValidatorListFlow() throws -> RecommendedValidatorListFlow? {
        guard let maxDelegations = maxDelegations,
              let recommendedCandidates = recommendedCandidates else {
            throw SelectValidatorsStartError.dataNotLoaded
        }

        guard !recommendedCandidates.isEmpty else {
            throw SelectValidatorsStartError.emptyRecommendedValidators
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
                   let minimumDelegationDecimal = Decimal.fromSubstrateAmount(
                       minimumDelegation,
                       precision: Int16(chainAsset.asset.precision)
                   ) {
                    if bonding.amount > minimumDelegationDecimal {
                        recommendedCandidates?.append(candidate)
                    }
                }
            }
        }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}

extension SelectValidatorsStartParachainViewModelState: SelectValidatorsStartParachainStrategyOutput {
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

    func didReceiveCollatorsApr(collatorsApr: [CollatorAprInfoProtocol]) {
        self.collatorsApr = collatorsApr

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
