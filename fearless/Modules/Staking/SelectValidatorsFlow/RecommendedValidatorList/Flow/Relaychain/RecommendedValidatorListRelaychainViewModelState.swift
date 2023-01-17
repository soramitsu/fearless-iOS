import Foundation

final class RecommendedValidatorListRelaychainInitiatedViewModelState: RecommendedValidatorListRelaychainViewModelState {
    let bonding: InitiatedBonding

    init(bonding: InitiatedBonding, validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.bonding = bonding

        super.init(validators: validators, maxTargets: maxTargets)
    }

    override func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        guard validators.isNotEmpty else {
            return nil
        }

        return .relaychainInitiated(
            targets: validators,
            maxTargets: maxTargets,
            bonding: bonding
        )
    }
}

final class RecommendedValidatorListRelaychainExistingViewModelState: RecommendedValidatorListRelaychainViewModelState {
    let bonding: ExistingBonding

    init(bonding: ExistingBonding, validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.bonding = bonding

        super.init(validators: validators, maxTargets: maxTargets)
    }

    override func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        guard validators.isNotEmpty else {
            return nil
        }

        return .relaychainExisting(
            targets: validators,
            maxTargets: maxTargets,
            bonding: bonding
        )
    }
}

class RecommendedValidatorListRelaychainViewModelState: RecommendedValidatorListViewModelState {
    var stateListener: RecommendedValidatorListModelStateListener?

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    private(set) var validators: [SelectedValidatorInfo]
    private(set) var maxTargets: Int

    init(validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.validators = validators
        self.maxTargets = maxTargets
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .relaychain(validatorInfo: validators[validatorIndex], address: nil)
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        assertionFailure("RecommendedValidatorListRelaychainViewModelState.selectValidatorsConfirmFlow error: Please use subclass to specify flow")
        return nil
    }
}
