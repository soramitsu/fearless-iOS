import Foundation

final class ValidatorInfoParachainViewModelState: ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener?
    let collatorInfo: ParachainStakingCandidateInfo

    var validatorAddress: String? {
        collatorInfo.address
    }

    init(collatorInfo: ParachainStakingCandidateInfo) {
        self.collatorInfo = collatorInfo
    }

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension ValidatorInfoParachainViewModelState: ValidatorInfoParachainStrategyOutput {
    func didSetup() {
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
