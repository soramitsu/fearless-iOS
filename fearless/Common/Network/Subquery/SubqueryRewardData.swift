import Foundation
import FearlessUtils
import BigInt

struct SubqueryRewardItemData {
    let eventId: String
    let timestamp: Int64
    let validatorAddress: AccountAddress
    let era: EraIndex
    let stashAddress: AccountAddress
    let amount: BigUInt
    let isReward: Bool

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
            let amount = BigUInt(amountString)
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
