import Foundation

class CustomValidatorListParachainViewModelState: CustomValidatorListViewModelState {
    var filter: CustomValidatorListFilter = .recommendedFilter()

    var viewModel: CustomValidatorListViewModel?

    var stateListener: CustomValidatorListModelStateListener?

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateViewModel(_ viewModel: CustomValidatorListViewModel) {
        self.viewModel = viewModel
    }

    func validatorInfoFlow(validatorIndex _: Int) -> ValidatorInfoFlow? {
        .parachain
    }

    func validatorSearchFlow() -> ValidatorSearchFlow? {
        .parachain
    }
}

extension CustomValidatorListParachainViewModelState: CustomValidatorListUserInputHandler {}
