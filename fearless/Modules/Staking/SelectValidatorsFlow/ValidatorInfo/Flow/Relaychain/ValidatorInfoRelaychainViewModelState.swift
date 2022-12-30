import Foundation

final class ValidatorInfoRelaychainViewModelState: ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener?
    var validatorInfo: ValidatorInfoProtocol?

    var validatorAddress: String? {
        validatorInfo?.address
    }

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }
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
