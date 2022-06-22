enum DelegationViewStatus {
    case active(countdown: String)
    case idle(countdown: String)
    case leaving(countdown: String)
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
}

struct DelegationViewModel: DelegationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: DelegationViewStatus
    let hasPrice: Bool
    let name: String?
}
