import Foundation

protocol RewardOrSlash {
    var amount: String { get }
    var isReward: Bool { get }
    var era: Int? { get }
    var validator: String? { get }
    var stash: String? { get }
    var eventIdx: String? { get }
    var assetId: String? { get }
}
