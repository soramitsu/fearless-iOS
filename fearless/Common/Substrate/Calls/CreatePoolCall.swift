import Foundation
import SSFUtils
import Web3

struct CreatePoolCall: Codable {
    @StringCodable var amount: BigUInt
    let root: MultiAddress
    let nominator: MultiAddress
    let stateToggler: MultiAddress
}

struct CreatePoolCallV2: Codable {
    @StringCodable var amount: BigUInt
    let root: MultiAddress
    let nominator: MultiAddress
    let bouncer: MultiAddress
}
