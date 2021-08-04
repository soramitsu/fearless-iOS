import Foundation
import FearlessUtils
import BigInt

struct SubqueryRewardItemData: Codable {
    let amount: BigUInt
    let isReward: Bool
    let timestamp: Int64

    init?(from json: JSON?, timestamp: Int64) {
        guard
            let json = json,
            let isReward = json.isReward?.boolValue,
            let amountString = json.amount?.stringValue,
            let amount = BigUInt(amountString)
        else { return nil }

        self.amount = amount
        self.isReward = isReward
        self.timestamp = timestamp
    }

    // TODO: delete init
    init(amount: BigUInt, isReward: Bool, timestamp: Int64) {
        self.amount = amount
        self.isReward = isReward
        self.timestamp = timestamp
    }
}
