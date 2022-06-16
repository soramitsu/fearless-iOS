protocol DelegationInfoCellModelDelegate: AnyObject {
    func manageDelegation()
}

class DelegationInfoCellModel {
//    let name: String
//    let stakedAmount: String
//    let stakedSum: String
//    let rewardAmount: String
//    let rewardSum: String
//    let status: StatusView.Status
//
    weak var delegate: DelegationInfoCellModelDelegate?
//
//    internal init() {
//
//    }
}

extension DelegationInfoCellModel: DelegationInfoCellDelegate {
    func manageButtonClicked() {
        delegate?.manageDelegation()
    }
}
