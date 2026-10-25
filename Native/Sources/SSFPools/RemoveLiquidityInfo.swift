import Foundation

public struct RemoveLiquidityInfo {
    public let dexId: String
    public let baseAsset: PooledAssetInfo
    public let targetAsset: PooledAssetInfo
    public let baseAssetAmount: Decimal
    public let targetAssetAmount: Decimal
    public let baseAssetReserves: Decimal
    public let totalIssuances: Decimal
    public let slippage: Decimal

    public init(
        dexId: String,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo,
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        baseAssetReserves: Decimal,
        totalIssuances: Decimal,
        slippage: Decimal
    ) {
        self.dexId = dexId
        self.baseAsset = baseAsset
        self.targetAsset = targetAsset
        self.baseAssetAmount = baseAssetAmount
        self.targetAssetAmount = targetAssetAmount
        self.baseAssetReserves = baseAssetReserves
        self.totalIssuances = totalIssuances
        self.slippage = slippage
    }

    public var amountMinA: Decimal {
        baseAssetAmount - baseAssetAmount / Decimal(100) * slippage
    }

    public var amountMinB: Decimal {
        targetAssetAmount - targetAssetAmount / Decimal(100) * slippage
    }

    public var assetDesired: Decimal {
        baseAssetAmount / baseAssetReserves * totalIssuances
    }
}
