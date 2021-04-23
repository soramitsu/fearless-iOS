enum RewardDetailsRow {
    case status(StakingRewardStatusViewModel)
    case date(StakingRewardDetailsSimpleLabelViewModel)
    case era(StakingRewardDetailsSimpleLabelViewModel)
    case reward(StakingRewardTokenUsdViewModel)
    case validatorInfo(AccountInfoViewModel)
    case destination(StakingRewardDetailsSimpleLabelViewModel)
}
