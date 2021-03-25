enum RewardDetailsRow {
    case status(StakingRewardStatus)
    case date(String)
    case era(String)
    case reward
}

extension RewardDetailsRow {

    var title: String {
        switch self {
        case .status:
            return R.string.localizable.stakingRewardDetailsStatus()
        case .date:
            return R.string.localizable.stakingRewardDetailsDate()
        case .era:
            return R.string.localizable.stakingRewardDetailsEra()
        case .reward:
            return R.string.localizable.stakingRewardDetailsReward()
        }
    }
}
