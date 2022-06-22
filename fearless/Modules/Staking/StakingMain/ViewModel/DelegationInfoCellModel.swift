import SoraFoundation

final class DelegationInfoCellModel {
    let moreHandler: () -> Void
    let statusHandler: () -> Void

    let contentViewModel: LocalizableResource<DelegationViewModelProtocol>

    init(
        contentViewModel: LocalizableResource<DelegationViewModelProtocol>,
        moreHandler: @escaping () -> Void,
        statusHandler: @escaping () -> Void
    ) {
        self.contentViewModel = contentViewModel
        self.moreHandler = moreHandler
        self.statusHandler = statusHandler
    }
}

extension DelegationInfoCellModel: StakingStateViewDelegate {
    func stakingStateViewDidReceiveMoreAction(_: StakingStateView) {
        moreHandler()
    }

    func stakingStateViewDidReceiveStatusAction(_: StakingStateView) {
        statusHandler()
    }
}
