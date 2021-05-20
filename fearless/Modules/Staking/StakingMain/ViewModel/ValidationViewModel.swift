import Foundation

enum ValidationViewStatus {
    case undefined
    case active
    case inactive
}

protocol ValidationViewModelProtocol {
    var totalStakedAmount: String { get }
    var totalStakedPrice: String { get }
    var totalRewardAmount: String { get }
    var totalRewardPrice: String { get }
    var status: ValidationViewStatus { get }
}

struct ValidationViewModel: ValidationViewModelProtocol {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let totalRewardAmount: String
    let totalRewardPrice: String
    let status: ValidationViewStatus
}
