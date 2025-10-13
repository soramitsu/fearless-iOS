import Foundation
import SSFModels
import SSFPools
import SSFStorageQueryKit
import SSFXCM
import BigInt

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

// MARK: - Lightweight service stubs for compile-time wiring

public typealias SigningWrapperData = XcmAssembly.SigningWrapperData

// Compatibility types used across Liquidity Pools code
public struct PoolApyInfo {
    public let apy: Decimal?
    public let poolId: String?

    public init(apy: Decimal?, poolId: String?) {
        self.apy = apy
        self.poolId = poolId
    }
}

public struct PolkaswapPoolReserves {
    public let reserves: BigUInt
    public let fee: BigUInt

    public init(reserves: BigUInt, fee: BigUInt) {
        self.reserves = reserves
        self.fee = fee
    }
}

public struct PolkaswapPoolReservesInfo {
    public let reserves: PolkaswapPoolReserves
    public let poolId: String?

    public init(reserves: PolkaswapPoolReserves, poolId: String? = nil) {
        self.reserves = reserves
        self.poolId = poolId
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
    // Legacy convenience used broadly in presenters; return nil by default
    func getPrice(for _: Any) -> PriceData? { nil }
}

public extension SSFPools.LiquidityPair {
    var dexId: String { "0" }
}

// Convenience mapping used by presenters when navigating from account pools
public extension SSFPools.AccountPool {
    var liquidityPair: SSFPools.LiquidityPair {
        SSFPools.LiquidityPair(
            pairId: poolId,
            chainId: chainId,
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            reserves: nil,
            apy: apy,
            reservesId: reservesId
        )
    }
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

private struct DummyPoolsOperationService: PoolsOperationService {
    func submit(liquidityOperation _: PoolOperation) async throws -> String { throw PoolsOperationServiceError.unexpectedError }
    func estimateFee(liquidityOperation _: PoolOperation) async throws -> BigUInt { throw PoolsOperationServiceError.unexpectedError }
}

public enum PolkaswapLiquidityPoolServiceAssembly {
    public static func buildService(for _: ChainModel, chainRegistry _: ChainRegistryProtocol) -> PolkaswapLiquidityPoolService { PolkaswapLiquidityPoolService() }

    public static func buildOperationService(
        for _: ChainModel,
        wallet _: SSFModels.MetaAccountModel,
        chainRegistry _: ChainRegistryProtocol,
        signingWrapperData _: SigningWrapperData
    ) throws -> PoolsOperationService { DummyPoolsOperationService() }
}

// Public initializers for SSFPools value types (memberwise inits are internal)
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

// Public initializer for RemoveLiquidityInfo used by presenters
public extension RemoveLiquidityInfo {
    init(
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
}

// Extra API surface used by Remove Liquidity interactor
public extension PolkaswapLiquidityPoolService {
    func fetchUserPool(assetIdPair _: AssetIdPair, accountId _: Data) async throws -> AccountPool? { nil }
    func fetchTotalIssuance(reservesId _: Data) async throws -> BigUInt? { nil }
}

// (removed) Network compatibility shims are defined centrally under Common/Compatibility
