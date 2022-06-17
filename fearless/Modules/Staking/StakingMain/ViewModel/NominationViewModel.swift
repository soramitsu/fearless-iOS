import Foundation

enum NominationViewStatus {
    enum ValidatorStatus {
        case undefined
        case active(EraIndex)
        case inactive(EraIndex)
        case waiting(eraCountdown: EraCountdown?, nominationEra: EraIndex)
    }

    enum CollatorStatus {
        case active(String)
        case idle(String)
        case leaving(String)
        case undefined
    }

    enum StatusInfo {
        case era(EraIndex)
        case countdown(String)
    }

    case relaychain(ValidatorStatus)
    case parachain(CollatorStatus)
}

protocol NominationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var totalRewardAmount: String { get }
    var totalRewardPrice: String { get }
    var status: NominationViewStatus { get }
    var hasPrice: Bool { get }
    var name: String? { get }
}

struct NominationViewModel: NominationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: NominationViewStatus
    let hasPrice: Bool
    let name: String?
}
