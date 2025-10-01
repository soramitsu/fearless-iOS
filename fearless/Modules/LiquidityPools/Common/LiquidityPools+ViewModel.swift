import Foundation
import SSFPolkaswap
import SSFModels
import SSFPools

// MARK: - Temporary compatibility shim (in-target) to unblock CI
// These definitions mirror the ones in Common/Compatibility to ensure Jenkins (which
// may not include new files yet) compiles LP modules. Remove after SPM alignment.
import SSFStorageQueryKit
import SSFXCM

public typealias SigningWrapperData = XcmAssembly.SigningWrapperData

public struct PoolApyInfo {
    public let apy: Decimal?
    public let poolId: String?

    public init(apy: Decimal?, poolId: String?) {
        self.apy = apy
        self.poolId = poolId
    }
}

public struct PolkaswapPoolReservesInfo {
    public let reserves: SSFPolkaswap.PolkaswapPoolReserves

    public init(reserves: SSFPolkaswap.PolkaswapPoolReserves) {
        self.reserves = reserves
    }
}

public struct AssetIdPair {
    public let baseAssetIdCode: String
    public let targetAssetIdCode: String

    public init(baseAssetIdCode: String, targetAssetIdCode: String) {
        self.baseAssetIdCode = baseAssetIdCode
        self.targetAssetIdCode = targetAssetIdCode
    }

    public var poolId: String { "\(baseAssetIdCode)-\(targetAssetIdCode)" }
}

public extension ChainModel {
    var assets: [AssetModel] { Array(tokens.tokens ?? []) }
}

public extension AssetModel {
    var currencyId: String { tokenProperties?.currencyId ?? id }
    var color: String { tokenProperties?.color ?? "" }
}

public extension SSFPools.LiquidityPair {
    var dexId: String { "0" }
}

public final class PolkaswapLiquidityPoolService {
    public init() {}

    public func subscribeLiquidityPool(assetIdPair _: AssetIdPair) async throws -> AsyncStream<CachedStorageResponse<LiquidityPair?>> { AsyncStream { $0.finish() } }
    public func subscribeUserPools(accountId _: Data) async throws -> AsyncStream<CachedStorageResponse<[AccountPool]>> { AsyncStream { $0.finish() } }
    public func subscribeAvailablePools() async throws -> AsyncStream<CachedStorageResponse<[LiquidityPair]>> { AsyncStream { $0.finish() } }
    public func subscribePoolReserves(assetIdPair _: AssetIdPair) async throws -> AsyncStream<CachedStorageResponse<PolkaswapPoolReservesInfo>> { AsyncStream { $0.finish() } }
    public func subscribePoolsReserves(pools _: [LiquidityPair]) async throws -> AsyncStream<CachedStorageResponse<[PolkaswapPoolReservesInfo]>> { AsyncStream { $0.finish() } }
    public func subscribePoolsAPY(poolIds _: [String]) async throws -> AsyncStream<[CachedStorageResponse<PoolApyInfo?>]> { AsyncStream { $0.finish() } }
}

public enum PolkaswapLiquidityPoolServiceAssembly {
    public static func buildService(for _: ChainModel, chainRegistry _: ChainRegistryProtocol) -> PolkaswapLiquidityPoolService { PolkaswapLiquidityPoolService() }
}

protocol LiquidityPoolsModelFactory {
    func buildReserves(
        pool: LiquidityPair,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal?
    func buildReserves(
        accountPool: AccountPool,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal?
}

final class LiquidityPoolsModelFactoryDefault: LiquidityPoolsModelFactory {
    func buildReserves(
        pool: LiquidityPair,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal? {
        let baseAsset = chain.assets.first(where: { $0.currencyId == pool.baseAssetId })
        let targetAsset = chain.assets.first(where: { $0.currencyId == pool.targetAssetId })

        guard let baseAsset, let targetAsset else {
            return nil
        }

        let poolReservesValue = (reservesInfo?.reserves.reserves).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(baseAsset.precision)) }
        let baseAssetPriceValue = (baseAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolFeeValue = (reservesInfo?.reserves.fee).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetAsset.precision)) }
        let targetAssetPriceValue = (targetAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolReservesFiatValue: Decimal? = poolReservesValue.flatMap { poolReserves in
            guard let baseAssetPriceValue, let poolFeeValue, let targetAssetPriceValue else {
                return nil
            }

            return (poolReserves * baseAssetPriceValue) + (poolFeeValue * targetAssetPriceValue)
        }

        return poolReservesFiatValue
    }

    func buildReserves(
        accountPool: AccountPool,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal? {
        let baseAsset = chain.assets.first(where: { $0.currencyId == accountPool.baseAssetId })
        let targetAsset = chain.assets.first(where: { $0.currencyId == accountPool.targetAssetId })

        guard let baseAsset, let targetAsset else {
            return nil
        }

        let poolReservesValue = (reservesInfo?.reserves.reserves).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(baseAsset.precision)) }
        let baseAssetPriceValue = (baseAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolFeeValue = (reservesInfo?.reserves.fee).flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetAsset.precision)) }
        let targetAssetPriceValue = (targetAssetPrice?.price).flatMap { Decimal(string: $0) }

        let poolReservesFiatValue: Decimal? = poolReservesValue.flatMap { poolReserves in
            guard let baseAssetPriceValue, let poolFeeValue, let targetAssetPriceValue else {
                return nil
            }

            return (poolReserves * baseAssetPriceValue) + (poolFeeValue * targetAssetPriceValue)
        }

        return poolReservesFiatValue
    }
}
