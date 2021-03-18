import Foundation

enum NominationViewStatus {
    case undefined
    case active(era: UInt32)
    case inactive(era: UInt32)
    case waiting
    case election
}

protocol NominationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var totalRewardAmount: String { get }
    var totalRewardPrice: String { get }
    var status: NominationViewStatus { get }
}

struct NominationViewModel: NominationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: NominationViewStatus
}
