import Foundation

final class ValidatorInfoParachainViewModelState: ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener?

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }

    let collatorInfo: ParachainStakingCandidateInfo

    init(collatorInfo: ParachainStakingCandidateInfo) {
        self.collatorInfo = collatorInfo
    }
}

extension ValidatorInfoParachainViewModelState: ValidatorInfoParachainStrategyOutput {
    func didSetup() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
