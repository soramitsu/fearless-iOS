import Foundation
import SoraFoundation
import CommonWallet

struct StakingAmountMainViewModel {
    let assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    let rewardDestinationViewModel: LocalizableResource<RewardDestinationViewModelProtocol>?
    let feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let inputViewModel: LocalizableResource<IAmountInputViewModel>?
    let continueAvailable: Bool
}
