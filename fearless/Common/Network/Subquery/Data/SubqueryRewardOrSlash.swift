import Foundation

struct SubqueryRewardOrSlash: Decodable {
    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
    let stash: String?
    let eventIdx: Int?
    let assetId: String?
}
