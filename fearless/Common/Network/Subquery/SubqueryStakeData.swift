import Foundation
import FearlessUtils
import BigInt

struct SubqueryStakeChangeData {
    let timestamp: Int64
    let address: AccountAddress
    let amount: BigUInt
    let type: SubqueryStakeChangeType

    enum SubqueryStakeChangeType: String {
        case bonded
        case unbonded
        case slashed
        case rewarded
    }

    init?(from json: JSON?) {
        guard
            let json = json,
            let timestampString = json.timestamp?.stringValue,
            let timestamp = Int64(timestampString),
            let address = json.address?.stringValue,
            let amountString = json.amount?.stringValue,
            let amount = BigUInt(amountString),
            let typeString = json.type?.stringValue,
            let type = SubqueryStakeChangeType(rawValue: typeString)
        else { return nil }

        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.type = type
    }
}

extension SubqueryStakeChangeData.SubqueryStakeChangeType {
    func title(for _: Locale) -> String {
        switch self {
        case .bonded:
            return "Bonded"
        case .unbonded:
            return "Unstake"
        case .rewarded:
            return "Reward"
        case .slashed:
            return "Stash"
        }
    }
}
