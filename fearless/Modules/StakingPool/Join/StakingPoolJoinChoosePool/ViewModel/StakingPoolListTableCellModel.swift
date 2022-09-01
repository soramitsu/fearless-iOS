import Foundation

protocol StakingPoolListTableCellModelDelegate: AnyObject {
    func showPoolInfo(poolId: String)
    func selectPool(poolId: String)
}

struct StakingPoolListTableCellModel {
    let isSelected: Bool
    let poolName: String
    let membersCountString: String
    let stakedAmountAttributedString: NSAttributedString
    let poolId: String
    weak var delegate: StakingPoolListTableCellModelDelegate?
}

extension StakingPoolListTableCellModel: StakingPoolListTableCellDelegate {
    func didTapInfoButton() {
        delegate?.showPoolInfo(poolId: poolId)
    }

    func didTapCell() {
        delegate?.selectPool(poolId: poolId)
    }
}
