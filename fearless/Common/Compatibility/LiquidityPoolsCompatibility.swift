import Foundation
import SSFModels
import SSFPools
import SSFPolkaswap
import SSFStorageQueryKit
import SSFXCM

// Temporary compatibility layer to unblock build while SSF APIs evolve.

// Align SigningWrapperData name with where it currently lives.
public typealias SigningWrapperData = XcmAssembly.SigningWrapperData

// Minimal APY info container (new SSF returns Decimal/APY lists).
public struct PoolApyInfo {
    public let apy: Decimal?
    public let poolId: String?

    public init(apy: Decimal?, poolId: String?) {
        self.apy = apy
        self.poolId = poolId
    }
}

// Wrap current reserves struct to expected name in app code.
public struct PolkaswapPoolReservesInfo {
    public let reserves: SSFPolkaswap.PolkaswapPoolReserves

    public init(reserves: SSFPolkaswap.PolkaswapPoolReserves) {
        self.reserves = reserves
    }
}

// Pair of asset IDs expected by Liquidity modules.
public struct AssetIdPair {
    public let baseAssetIdCode: String
    public let targetAssetIdCode: String

    public init(baseAssetIdCode: String, targetAssetIdCode: String) {
        self.baseAssetIdCode = baseAssetIdCode
        self.targetAssetIdCode = targetAssetIdCode
    }

    public var poolId: String { "\(baseAssetIdCode)-\(targetAssetIdCode)" }
}

// Backward helpers for frequently used conveniences.
public extension ChainModel {
    // Old code used chain.assets; map to tokens set if available.
    var assets: [AssetModel] { Array(tokens.tokens ?? []) }
}

public extension AssetModel {
    // Old code accessed currencyId/color directly on AssetModel.
    var currencyId: String { tokenProperties?.currencyId ?? id }
    var color: String { tokenProperties?.color ?? "" }

    // Legacy placeholder; project code guards usage with optionals.
    func getPrice(for _: Currency) -> PriceData? { nil }
}

public extension SSFPools.LiquidityPair {
    // Legacy access used a dexId; return a safe default.
    var dexId: String { "0" }
}

// No-op service implementations to satisfy existing assemblies during transition.
public final class PolkaswapLiquidityPoolService {
    public init() {}

    public func subscribeLiquidityPool(assetIdPair _: AssetIdPair) async throws -> AsyncStream<CachedStorageResponse<LiquidityPair?>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func subscribeUserPools(accountId _: Data) async throws -> AsyncStream<CachedStorageResponse<[AccountPool]>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func subscribeAvailablePools() async throws -> AsyncStream<CachedStorageResponse<[LiquidityPair]>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func subscribePoolReserves(assetIdPair _: AssetIdPair) async throws -> AsyncStream<CachedStorageResponse<PolkaswapPoolReservesInfo>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func subscribePoolsReserves(pools _: [LiquidityPair]) async throws -> AsyncStream<CachedStorageResponse<[PolkaswapPoolReservesInfo]>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func subscribePoolsAPY(poolIds _: [String]) async throws -> AsyncStream<[CachedStorageResponse<PoolApyInfo?>]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

private struct DummyPoolsOperationService: PoolsOperationService {
    func submit(liquidityOperation _: PoolOperation) async throws -> String {
        throw PoolsOperationServiceError.unexpectedError
    }

    func estimateFee(liquidityOperation _: PoolOperation) async throws -> BigUInt {
        throw PoolsOperationServiceError.unexpectedError
    }
}

public enum PolkaswapLiquidityPoolServiceAssembly {
    public static func buildService(
        for _: ChainModel,
        chainRegistry _: ChainRegistryProtocol
    ) -> PolkaswapLiquidityPoolService {
        PolkaswapLiquidityPoolService()
    }

    public static func buildOperationService(
        for _: ChainModel,
        wallet _: SSFModels.MetaAccountModel,
        chainRegistry _: ChainRegistryProtocol,
        signingWrapperData _: SigningWrapperData
    ) throws -> PoolsOperationService {
        DummyPoolsOperationService()
    }
}

