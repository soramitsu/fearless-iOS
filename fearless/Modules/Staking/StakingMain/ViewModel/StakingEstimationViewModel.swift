import Foundation
import CommonWallet
import SoraFoundation

protocol StakingEstimationViewModelProtocol {
    var assetBalance: LocalizableResource<AssetBalanceViewModelProtocol> { get }
    var monthlyReward: LocalizableResource<RewardViewModelProtocol> { get }
    var yearlyReward: LocalizableResource<RewardViewModelProtocol> { get }
    var asset: WalletAsset { get }
    var inputLimit: Decimal { get }
    var amount: Decimal? { get }
}

struct StakingEstimationViewModel: StakingEstimationViewModelProtocol {
    let assetBalance: LocalizableResource<AssetBalanceViewModelProtocol>
    let monthlyReward: LocalizableResource<RewardViewModelProtocol>
    let yearlyReward: LocalizableResource<RewardViewModelProtocol>
    let asset: WalletAsset
    let inputLimit: Decimal
    let amount: Decimal?
}
