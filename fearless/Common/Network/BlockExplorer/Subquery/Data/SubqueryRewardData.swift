import Foundation
import SSFUtils
import BigInt

struct SubqueryRewardItemData: Equatable, Codable {
    let eventId: String
    let timestamp: Int64
    let validatorAddress: AccountAddress
    let era: EraIndex
    let stashAddress: AccountAddress
    let amount: BigUInt
    let isReward: Bool
}

extension SubqueryRewardItemData {
    init?(from json: JSON) {
        guard
            let eventId = json.id?.stringValue,
            let timestampString = json.timestamp?.stringValue,
            let timestamp = Int64(timestampString),
            let validatorAddress = json.reward?.validator?.stringValue,
            let stashAddress = json.address?.stringValue,
            let isReward = json.reward?.isReward?.boolValue,
            let era = json.reward?.era?.unsignedIntValue,
            let amountString = json.reward?.amount?.stringValue,
            let amount = BigUInt(string: amountString)
        else { return nil }

        self.eventId = eventId
        self.timestamp = timestamp
        self.validatorAddress = validatorAddress
        self.era = EraIndex(era)
        self.stashAddress = stashAddress
        self.amount = amount
        self.isReward = isReward
    }
}
