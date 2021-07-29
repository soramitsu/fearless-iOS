import Foundation
import FearlessUtils
import BigInt

struct SubqueryRewardItemData: Codable {
    let amount: String
    let isReward: Bool
    let timestamp: Int64

    init?(from json: JSON?, timestamp: Int64) {
        guard
            let json = json,
            let isReward = json.isReward?.boolValue,
            let amount = json.amount?.stringValue
        else { return nil }

        self.amount = amount
        self.isReward = isReward
        self.timestamp = timestamp
    }

    // TODO: delete init
    init(amount: String, isReward: Bool, timestamp: Int64) {
        self.amount = amount
        self.isReward = isReward
        self.timestamp = timestamp
    }
}
