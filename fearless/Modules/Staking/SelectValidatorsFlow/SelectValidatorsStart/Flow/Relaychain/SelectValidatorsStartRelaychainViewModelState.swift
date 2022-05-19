import Foundation

class SelectValidatorsStartRelaychainViewModelState: SelectValidatorsStartViewModelState {
    let initialTargets: [SelectedValidatorInfo]?
    let existingStashAddress: AccountAddress?

    var electedValidators: [AccountAddress: ElectedValidatorInfo]?
    var recommendedValidators: [ElectedValidatorInfo]?
    var selectedValidators: SharedList<SelectedValidatorInfo>?
    var maxNominations: Int?

    var stateListener: SelectValidatorsStartModelStateListener?

    init(
        initialTargets: [SelectedValidatorInfo]?,
        existingStashAddress: AccountAddress?
    ) {
        self.initialTargets = initialTargets
        self.existingStashAddress = existingStashAddress
    }

    func setStateListener(_ stateListener: SelectValidatorsStartModelStateListener?) {
        self.stateListener = stateListener
    }

    var recommendedValidatorListFlow: RecommendedValidatorListFlow? {
        guard let recommendedValidators = recommendedValidators, let maxTargets = maxNominations else {
            return nil
        }

        let recommendedValidatorList = recommendedValidators.map { $0.toSelected(for: existingStashAddress) }

        return .relaychain(validators: recommendedValidatorList, maxTargets: maxTargets)
    }

    var customValidatorListFlow: CustomValidatorListFlow? {
        guard let electedValidators = electedValidators, let selectedValidators = selectedValidators, let maxTargets = maxNominations else {
            return nil
        }

        let electedValidatorList = electedValidators.values.map { $0.toSelected(for: existingStashAddress) }
        let recommendedValidatorList = recommendedValidators?.map {
            $0.toSelected(for: existingStashAddress)
        } ?? []

        return .relaychain(
            validatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidators,
            maxTargets: maxTargets
        )
    }

    private func updateSelectedValidatorsIfNeeded() {
        guard
            let electedValidators = electedValidators,
            let maxNominations = maxNominations,
            selectedValidators == nil else {
            return
        }

        let selectedValidatorList = initialTargets?.map { target in
            electedValidators[target.address]?.toSelected(for: existingStashAddress) ?? target
        }
        .sorted { $0.stakeReturn > $1.stakeReturn }
        .prefix(maxNominations) ?? []

        selectedValidators = SharedList(items: selectedValidatorList)
    }

    private func updateRecommendedValidators() {
        guard
            let electedValidators = electedValidators,
            let maxNominations = maxNominations else {
            return
        }

        let resultLimit = min(electedValidators.count, maxNominations)
        let recomendedValidators = RecommendationsComposer(
            resultSize: resultLimit,
            clusterSizeLimit: StakingConstants.targetsClusterLimit
        ).compose(from: Array(electedValidators.values))

        recommendedValidators = recomendedValidators
    }
}

extension SelectValidatorsStartRelaychainViewModelState: SelectValidatorsStartRelaychainStrategyOutput {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>) {
        switch result {
        case let .success(validators):
            electedValidators = validators.reduce(
                into: [AccountAddress: ElectedValidatorInfo]()
            ) { dict, validator in
                dict[validator.address] = validator
            }

            updateSelectedValidatorsIfNeeded()
            updateRecommendedValidators()

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMaxNominations(result: Result<Int, Error>) {
        switch result {
        case let .success(maxNominations):
            self.maxNominations = maxNominations

            stateListener?.modelStateDidChanged(viewModelState: self)
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
