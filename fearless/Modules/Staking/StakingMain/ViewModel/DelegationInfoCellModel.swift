import SoraFoundation

protocol DelegationInfoCellModelDelegate: AnyObject {
    func didReceiveMoreAction(delegationInfo: ParachainStakingDelegationInfo)
    func didReceiveStatusAction()
}

final class DelegationInfoCellModel {
    weak var delegate: DelegationInfoCellModelDelegate?

    let contentViewModel: LocalizableResource<DelegationViewModelProtocol>
    let delegationInfo: ParachainStakingDelegationInfo
    var locale: Locale?

    init(
        contentViewModel: LocalizableResource<DelegationViewModelProtocol>,
        delegationInfo: ParachainStakingDelegationInfo
    ) {
        self.contentViewModel = contentViewModel
        self.delegationInfo = delegationInfo
    }
}

extension DelegationInfoCellModel: StakingStateViewDelegate {
    func stakingStateViewDidReceiveMoreAction(_: StakingStateView) {
        delegate?.didReceiveMoreAction(delegationInfo: delegationInfo)
    }

    func stakingStateViewDidReceiveStatusAction(_: StakingStateView) {
        delegate?.didReceiveStatusAction()
    }
}
