import Foundation

enum NominationViewStatus {
    case undefined
    case active(era: EraIndex)
    case inactive(era: EraIndex)
    case waiting(eraCountdown: EraCountdown?, nominationEra: EraIndex)
}

protocol NominationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var totalRewardAmount: String { get }
    var totalRewardPrice: String { get }
    var status: NominationViewStatus { get }
    var hasPrice: Bool { get }
    var redeemableViewModel: StakingUnitInfoViewModel? { get }
    var unstakingViewModel: StakingUnitInfoViewModel? { get }
}

struct NominationViewModel: NominationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: NominationViewStatus
    let hasPrice: Bool
    var redeemableViewModel: StakingUnitInfoViewModel?
    var unstakingViewModel: StakingUnitInfoViewModel?
}
