import BigInt
import Foundation
@testable import SSFPolkaswap

/// Builds pool reserves, whose memberwise initializer is internal to SSFPolkaswap.
enum CovDLiquidityReserves {
    static func make(poolId: String, reserves: BigUInt, fee: BigUInt) -> PolkaswapPoolReservesInfo {
        PolkaswapPoolReservesInfo(poolId: poolId, reserves: PolkaswapPoolReserves(reserves: reserves, fee: fee))
    }
}
