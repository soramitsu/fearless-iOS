import Foundation

// swiftlint:disable type_name
// swiftlint:disable line_length
final class SelectValidatorsStartRelaychainExistingViewModelState: SelectValidatorsStartRelaychainViewModelState {
    let bonding: ExistingBonding

    init(
        bonding: ExistingBonding,
        initialTargets: [SelectedValidatorInfo]?,
        existingStashAddress: AccountAddress?
    ) {
        self.bonding = bonding

        super.init(
            initialTargets: initialTargets,
            existingStashAddress: existingStashAddress
        )
    }

    override var customValidatorListFlow: CustomValidatorListFlow? {
        guard let electedValidators = electedValidators,
              let selectedValidators = selectedValidators,
              let maxTargets = maxNominations else {
            return nil
        }

        let electedValidatorList = electedValidators.values.map { $0.toSelected(for: existingStashAddress) }
        let recommendedValidatorList = recommendedValidators?.map {
            $0.toSelected(for: existingStashAddress)
        } ?? []

        return .relaychainExisting(
            validatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidators,
            maxTargets: maxTargets,
            bonding: bonding
        )
    }

    override func recommendedValidatorListFlow() throws -> RecommendedValidatorListFlow? {
        guard let recommendedValidators = recommendedValidators, let maxTargets = maxNominations else {
            throw SelectValidatorsStartError.dataNotLoaded
        }

        let recommendedValidatorList = recommendedValidators.map { $0.toSelected(for: existingStashAddress) }

        return .relaychainExisting(validators: recommendedValidatorList, maxTargets: maxTargets, bonding: bonding)
    }
}

final class SelectValidatorsStartRelaychainInitiatedViewModelState: SelectValidatorsStartRelaychainViewModelState {
    let bonding: InitiatedBonding

    init(
        bonding: InitiatedBonding,
        initialTargets: [SelectedValidatorInfo]?,
        existingStashAddress: AccountAddress?
    ) {
        self.bonding = bonding

        super.init(
            initialTargets: initialTargets,
            existingStashAddress: existingStashAddress
        )
    }

    override var customValidatorListFlow: CustomValidatorListFlow? {
        guard let electedValidators = electedValidators,
              let selectedValidators = selectedValidators,
              let maxTargets = maxNominations else {
            return nil
        }

        let electedValidatorList = electedValidators.values.map { $0.toSelected(for: existingStashAddress) }
        let recommendedValidatorList = recommendedValidators?.map {
            $0.toSelected(for: existingStashAddress)
        } ?? []

        return .relaychainInitiated(
            validatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidators,
            maxTargets: maxTargets,
            bonding: bonding
        )
    }

    override func recommendedValidatorListFlow() throws -> RecommendedValidatorListFlow? {
        guard let recommendedValidators = recommendedValidators, let maxTargets = maxNominations else {
            throw SelectValidatorsStartError.dataNotLoaded
        }

        let recommendedValidatorList = recommendedValidators.map { $0.toSelected(for: existingStashAddress) }

        return .relaychainInitiated(validators: recommendedValidatorList, maxTargets: maxTargets, bonding: bonding)
    }
}

class SelectValidatorsStartRelaychainViewModelState: SelectValidatorsStartViewModelState {
    let initialTargets: [SelectedValidatorInfo]?
    let existingStashAddress: AccountAddress?
    private(set) var electedValidators: [AccountAddress: ElectedValidatorInfo]?
    private(set) var recommendedValidators: [ElectedValidatorInfo]?
    private(set) var selectedValidators: SharedList<SelectedValidatorInfo>?
    private(set) var maxNominations: Int?
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

    func recommendedValidatorListFlow() throws -> RecommendedValidatorListFlow? {
        assertionFailure("SelectValidatorsStartRelaychainViewModelState.recommendedValidatorListFlow error: Please use subclass to specify flow")
        return nil
    }

    var customValidatorListFlow: CustomValidatorListFlow? {
        assertionFailure("SelectValidatorsStartRelaychainViewModelState.customValidatorListFlow error: Please use subclass to specify flow")
        return nil
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
        ).compose(from: Array(electedValidators.values.filter { $0.elected }))

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
