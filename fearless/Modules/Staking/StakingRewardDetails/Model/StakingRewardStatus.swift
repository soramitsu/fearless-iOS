import UIKit.UIImage

enum StakingRewardStatus {
    case claimable
    case received
}

extension StakingRewardStatus {

    var text: String {
        switch self {
        case .claimable:
            return R.string.localizable.stakingRewardDetailsStatusClaimable()
        case .received:
            return R.string.localizable.stakingRewardDetailsStatusReceived()
        }
    }

    var icon: UIImage? {
        switch self {
        case .claimable:
            return R.image.iconTxPending()
        case .received:
            return R.image.iconValid()
        }
    }
}
