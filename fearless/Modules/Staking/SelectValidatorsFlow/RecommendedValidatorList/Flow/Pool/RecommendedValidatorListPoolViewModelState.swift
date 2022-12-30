import Foundation

// swiftlint:disable type_name
final class RecommendedValidatorListPoolInitiatedViewModelState: RecommendedValidatorListPoolViewModelState {
    let bonding: InitiatedBonding
    let poolId: UInt32

    init(poolId: UInt32, bonding: InitiatedBonding, validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.bonding = bonding
        self.poolId = poolId

        super.init(validators: validators, maxTargets: maxTargets)
    }

    override func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        .poolInitiated(poolId: poolId, targets: validators, maxTargets: maxTargets, bonding: bonding)
    }
}

final class RecommendedValidatorListPoolExistingViewModelState: RecommendedValidatorListPoolViewModelState {
    let bonding: ExistingBonding
    let poolId: UInt32

    init(poolId: UInt32, bonding: ExistingBonding, validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.bonding = bonding
        self.poolId = poolId

        super.init(validators: validators, maxTargets: maxTargets)
    }

    override func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        guard !validators.isEmpty else {
            return nil
        }

        return .poolExisting(
            poolId: poolId,
            targets: validators,
            maxTargets: maxTargets,
            bonding: bonding
        )
    }
}

class RecommendedValidatorListPoolViewModelState: RecommendedValidatorListViewModelState {
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
        .pool(validatorInfo: validators[validatorIndex], address: nil)
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        assertionFailure("RecommendedValidatorListRelaychainViewModelState.selectValidatorsConfirmFlow error: Please use subclass to specify flow")
        return nil
    }
}
