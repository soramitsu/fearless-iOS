import Foundation
import FearlessUtils
import BigInt

struct CreatePoolCall: Codable {
    @StringCodable var amount: BigUInt
    let root: AccountId
    let nominator: AccountId
    let stateToggler: AccountId
}
