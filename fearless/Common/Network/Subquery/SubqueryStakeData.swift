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

    init(timestamp: Int64, address: AccountAddress, amount: BigUInt, type: SubqueryStakeChangeType) {
        self.timestamp = timestamp
        self.address = address
        self.amount = amount
        self.type = type
    }
}

extension SubqueryStakeChangeData.SubqueryStakeChangeType {
    func title(for locale: Locale) -> String {
        switch self {
        case .bonded:
            return R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
        case .unbonded:
            return R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages)
        case .rewarded:
            return R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
        case .slashed:
            return R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        }
    }
}
