import Foundation

final class ValidatorInfoParachainViewModelState: ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener?

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }
}
