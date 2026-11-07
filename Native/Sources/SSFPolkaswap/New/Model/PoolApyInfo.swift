import Foundation

public struct PoolApyInfo {
    public let poolId: String
    public let apy: Decimal?

    public init(poolId: String, apy: Decimal?) {
        self.poolId = poolId
        self.apy = apy
    }
}
