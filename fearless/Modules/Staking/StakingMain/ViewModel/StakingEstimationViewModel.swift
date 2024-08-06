import Foundation

import SoraFoundation
import SSFModels

struct PeriodRewardViewModel {
    let monthlyReward: RewardViewModelProtocol
    let yearlyReward: RewardViewModelProtocol
}

struct StakingEstimationViewModel {
    let assetBalance: LocalizableResource<AssetBalanceViewModelProtocol>
    let rewardViewModel: LocalizableResource<PeriodRewardViewModel>?
    let assetInfo: AssetBalanceDisplayInfo
    let inputLimit: Decimal
    let amount: Decimal?
}
