import Foundation
import BigInt
import FearlessUtils

struct StakingPool: Decodable {
    @StringCodable var points: BigUInt
    let state: StakingPoolState
    @StringCodable var memberCounter: UInt32
    let roles: StakingPoolRoles
}
