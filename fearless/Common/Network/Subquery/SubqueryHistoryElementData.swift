import Foundation
import FearlessUtils

struct SubqueryHistoryElementData {
    let id: String
    let timestamp: Int64
    let address: AccountAddress
    let reward: SubqueryRewardItemData?

    init?(from json: JSON) {
        guard
            let id = json.id?.stringValue,
            let timestampString = json.timestamp?.stringValue,
            let timestamp = Int64(timestampString),
            let address = json.address?.stringValue
        else { return nil }

        self.id = id
        self.timestamp = timestamp
        self.address = address
        reward = SubqueryRewardItemData(from: json.reward, timestamp: timestamp)
    }
}
