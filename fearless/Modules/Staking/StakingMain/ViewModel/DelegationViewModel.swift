import Foundation

enum DelegationViewStatus {
    case active(countdown: TimeInterval?)
    case idle(countdown: TimeInterval?)
    case leaving(countdown: TimeInterval?)
    case undefined
}

protocol DelegationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var totalRewardAmount: String { get }
    var totalRewardPrice: String { get }
    var status: DelegationViewStatus { get }
    var hasPrice: Bool { get }
    var name: String? { get }
    var nextRoundInterval: TimeInterval? { get }
}

struct DelegationViewModel: DelegationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: DelegationViewStatus
    let hasPrice: Bool
    let name: String?
    let nextRoundInterval: TimeInterval?
}
