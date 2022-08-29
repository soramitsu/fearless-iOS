import Foundation

enum DelegationViewStatus {
    case active(round: UInt32)
    case idle(countdown: TimeInterval?)
    case leaving(countdown: TimeInterval?)
    case readyToUnlock
    case lowStake
    case undefined
}

protocol DelegationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var apr: String { get }
    var status: DelegationViewStatus { get }
    var hasPrice: Bool { get }
    var name: String? { get }
    var nextRoundInterval: TimeInterval? { get }
}

struct DelegationViewModel: DelegationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let apr: String
    let status: DelegationViewStatus
    let hasPrice: Bool
    let name: String?
    let nextRoundInterval: TimeInterval?
}
