import Foundation
import BigInt
import SSFUtils

struct StakingPoolInfo: Decodable {
    @StringCodable var points: BigUInt
    let state: StakingPoolState
    @StringCodable var memberCounter: UInt32
    let roles: StakingPoolRoles
}

struct StakingPool: Decodable {
    let id: String
    let info: StakingPoolInfo
    let name: String

    func byReplacingName(_ name: String) -> StakingPool {
        StakingPool(
            id: id,
            info: info,
            name: name
        )
    }
}
