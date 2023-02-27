import Foundation

protocol RewardOrSlashData {
    var identifier: String { get }
    var timestamp: String { get }
    var address: String { get }
    var rewardInfo: RewardOrSlash? { get }
}
