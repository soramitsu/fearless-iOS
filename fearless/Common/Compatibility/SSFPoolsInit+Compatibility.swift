import Foundation
import SSFPools

// Provide public initializers for SSFPools value types that expose public
// members but lack public memberwise initializers.

public extension PooledAssetInfo {
    init(id: String, precision: Int16) {
        self.id = id
        self.precision = precision
    }
}

public extension SupplyLiquidityInfo {
    init(
        dexId: String,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo,
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        slippage: Decimal
    ) {
        self.dexId = dexId
        self.baseAsset = baseAsset
        self.targetAsset = targetAsset
        self.baseAssetAmount = baseAssetAmount
        self.targetAssetAmount = targetAssetAmount
        self.slippage = slippage
    }
}
