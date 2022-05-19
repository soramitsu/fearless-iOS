import Foundation

class SelectValidatorsStartParachainViewModelState: SelectValidatorsStartViewModelState {
    var maxDelegations: Int?
    var selectedCandidates: [ParachainStakingCandidate]?

    var stateListener: SelectValidatorsStartModelStateListener?

    func setStateListener(_ stateListener: SelectValidatorsStartModelStateListener?) {
        self.stateListener = stateListener
    }

    var customValidatorListFlow: CustomValidatorListFlow? {
        .parachain
    }

    var recommendedValidatorListFlow: RecommendedValidatorListFlow? {
        .parachain
    }
}

extension SelectValidatorsStartParachainViewModelState: SelectValidatorsStartParachainStrategyOutput {
    func didReceiveMaxDelegations(result: Result<Int, Error>) {
        switch result {
        case let .success(maxDelegations):
            self.maxDelegations = maxDelegations

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveSelectedCandidates(selectedCandidates: [ParachainStakingCandidate]) {
        self.selectedCandidates = selectedCandidates

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
