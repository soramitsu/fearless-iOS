import Foundation

final class ValidatorInfoRelaychainViewModelState: ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener?

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }

    var validatorInfo: ValidatorInfoProtocol?
}

extension ValidatorInfoRelaychainViewModelState: ValidatorInfoRelaychainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: ValidatorInfoProtocol) {
        self.validatorInfo = validatorInfo

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveError(_ error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func didStartLoading() {
        stateListener?.didStartLoading()
    }
}
