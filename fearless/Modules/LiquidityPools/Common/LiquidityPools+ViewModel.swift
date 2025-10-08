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
