import Foundation
import CommonWallet
import SoraFoundation

protocol StakingEstimationViewModelProtocol {
    var assetBalance: AssetBalanceViewModelProtocol { get }
    var monthlyReward: RewardViewModelProtocol { get }
    var yearlyReward: RewardViewModelProtocol { get }
    var asset: WalletAsset { get }
}

struct StakingEstimationViewModel: StakingEstimationViewModelProtocol {
    let assetBalance: AssetBalanceViewModelProtocol
    let monthlyReward: RewardViewModelProtocol
    let yearlyReward: RewardViewModelProtocol
    let asset: WalletAsset
}
