import BigInt
import Foundation
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFStorageQueryKit
import SSFUtils
import XCTest

@testable import fearless

final class CovDPoolUpstreamStub: SSFPolkaswap.PolkaswapLiquidityPoolService {
    var pools: [LiquidityPair] = []
    var userPools: [AccountPool] = []
    var apys: [PoolApyInfo] = []
    var error: Error?

    func fetchAvailablePools() async throws -> [LiquidityPair] {
        if let error { throw error }
        return pools
    }

    func fetchUserPools(accountId _: Data) async throws -> [AccountPool] {
        if let error { throw error }
        return userPools
    }

    func fetchPoolsAPY() async throws -> [PoolApyInfo] {
        if let error { throw error }
        return apys
    }

    func fetchReserves(pools _: [LiquidityPair]) async throws -> [PolkaswapPoolReservesInfo] { [] }

    func subscribeAvailablePools() async throws -> AsyncThrowingStream<CachedStorageResponse<[LiquidityPair]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribeUserPools(accountId _: Data) async throws -> AsyncThrowingStream<CachedStorageResponse<[LiquidityPair]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribePoolReserves(pools _: [LiquidityPair]) async throws -> AsyncThrowingStream<CachedStorageResponse<[PolkaswapPoolReservesInfo]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

final class CovDPoolStorageStub: PoolXykStorage {
    var values: [PolkaswapPoolReservesInfo] = []
    var issuance: TotalIssuanceByReservesId = [:]
    var error: Error?

    func totalIssuance(chain _: ChainModel) async throws -> TotalIssuanceByReservesId {
        if let error { throw error }
        return issuance
    }

    func reserves(pairs _: [AssetIdPair], chain _: ChainModel) async throws -> [PolkaswapPoolReservesInfo] {
        if let error { throw error }
        return values
    }

    func accountPools(accountId _: Data, chain _: ChainModel) async throws -> [UserPool] { [] }
    func properties(pairs _: [AssetIdPair], chain _: ChainModel) async throws -> [AssetIdPair: LiquidityPoolProperties] { [:] }
    func properties(baseAssetIds _: [SSFPolkaswap.PolkaswapDexInfoAssetId], chain _: ChainModel) async throws -> [AssetIdPair: LiquidityPoolProperties] { [:] }
    func poolProviders(properties _: [LiquidityPoolProperties], accountId _: Data, chain _: ChainModel) async throws -> [PoolProvidersStorageKey: BigUInt] { [:] }

    func subscribeTotalIssuance(chain _: ChainModel) async -> AsyncThrowingStream<CachedStorageResponse<TotalIssuanceByReservesId>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribeProperties(
        baseAssetIds _: [SSFPolkaswap.PolkaswapDexInfoAssetId], chain _: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribeProperties(
        pairs _: [AssetIdPair], chain _: ChainModel
    ) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: LiquidityPoolProperties]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribeAccountPools(
        accountId _: Data, chain _: ChainModel
    ) async -> AsyncThrowingStream<CachedStorageResponse<[ScaleTuple<Data, SSFUtils.SoraAssetId>: [SSFUtils.SoraAssetId]]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func subscribeReserves(
        pairs _: [AssetIdPair], chain _: ChainModel
    ) async throws -> AsyncThrowingStream<CachedStorageResponse<[AssetIdPair: PolkaswapPoolReserves]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

final class CovDPoolHarness {
    let chain = CovDLiquidityFixtures.chain()
    let upstream = CovDPoolUpstreamStub()
    let storage = CovDPoolStorageStub()
    let reserveId = Data(repeating: 1, count: 32)
    var pair: LiquidityPair { CovDLiquidityFixtures.pair(chain, reservesId: reserveId.toHex(includePrefix: true)) }
    var assetPair: AssetIdPair { AssetIdPair(baseAssetIdCode: pair.baseAssetId, targetAssetIdCode: pair.targetAssetId) }
    var service: fearless.PolkaswapLiquidityPoolService {
        fearless.PolkaswapLiquidityPoolService(upstream: upstream, poolStorage: storage, chain: chain)
    }

    init() throws {
        upstream.pools = [pair]
        upstream.userPools = [CovDLiquidityFixtures.accountPool(chain, reservesId: reserveId.toHex(includePrefix: true))]
        let address = try fearless.AddressFactory.address(for: reserveId, chain: chain)
        upstream.apys = [PoolApyInfo(poolId: address, apy: 12)]
        storage.values = [CovDLiquidityReserves.make(poolId: pair.pairId, reserves: 100, fee: 200)]
        storage.issuance = [reserveId: 500]
    }

    var supply: SupplyLiquidityInfo {
        SupplyLiquidityInfo(
            dexId: "0", baseAsset: PooledAssetInfo(id: pair.baseAssetId, precision: 18),
            targetAsset: PooledAssetInfo(id: pair.targetAssetId, precision: 18),
            baseAssetAmount: 1, targetAssetAmount: 2, slippage: 0.5
        )
    }

    var removal: RemoveLiquidityInfo {
        RemoveLiquidityInfo(
            dexId: "0", baseAsset: PooledAssetInfo(id: pair.baseAssetId, precision: 18),
            targetAsset: PooledAssetInfo(id: pair.targetAssetId, precision: 18),
            baseAssetAmount: 1, targetAssetAmount: 2, baseAssetReserves: 100, totalIssuances: 500, slippage: 0.5
        )
    }
}

final class CovDPoolServiceTests: XCTestCase {
    func testStreamsReturnRemoteValuesAndFinish() async throws {
        let fixture = try CovDPoolHarness()
        let service = fixture.service
        var pools: [String] = []
        for await response in try await service.subscribeAvailablePools() {
            XCTAssertEqual(response.type, .remote)
            pools += response.value?.map(\.pairId) ?? []
        }
        XCTAssertEqual(pools, [fixture.pair.pairId])
        for await response in try await service.subscribeLiquidityPool(assetIdPair: fixture.assetPair) {
            XCTAssertEqual((response.value ?? nil)?.pairId, fixture.pair.pairId)
        }
        var users: [String] = []
        for await response in try await service.subscribeUserPools(accountId: Data([1])) {
            users += response.value?.map(\.poolId) ?? []
        }
        XCTAssertEqual(users, [fixture.pair.pairId])
        for await response in try await service.subscribePoolReserves(assetIdPair: fixture.assetPair) {
            XCTAssertEqual(response.value?.reserves.reserves, 100)
            XCTAssertEqual(response.value?.reserves.fee, 200)
        }
        for await response in try await service.subscribePoolsReserves(pools: fixture.upstream.pools) {
            XCTAssertEqual(response.value?.map(\.poolId), [fixture.pair.pairId])
        }
        for await response in try await service.subscribePoolsAPY(poolIds: fixture.upstream.apys.map(\.poolId)) {
            XCTAssertEqual(response.count, 1)
            XCTAssertEqual((response.first?.value ?? nil)?.apy, 12)
        }
        let issuance = try await service.fetchTotalIssuance(reservesId: fixture.reserveId)
        XCTAssertEqual(issuance, 500)
        let user = try await service.fetchUserPool(assetIdPair: fixture.assetPair, accountId: Data([1]))
        XCTAssertEqual(user?.baseAssetPooled, 4)
    }

    func testMissingAndAmbiguousPoolsNeverSelectAnArbitraryMatch() async throws {
        let fixture = try CovDPoolHarness()
        fixture.upstream.pools = [fixture.pair, fixture.pair]
        for await response in try await fixture.service.subscribeLiquidityPool(assetIdPair: fixture.assetPair) {
            XCTAssertNil(response.value ?? nil)
        }
        fixture.upstream.pools = []
        for await response in try await fixture.service.subscribeLiquidityPool(assetIdPair: fixture.assetPair) {
            XCTAssertNil(response.value ?? nil)
        }
        fixture.upstream.userPools += fixture.upstream.userPools
        do {
            _ = try await fixture.service.fetchUserPool(assetIdPair: fixture.assetPair, accountId: Data())
            XCTFail("Duplicate account pools must fail")
        } catch { XCTAssertTrue(error is PoolsOperationServiceError) }
        fixture.upstream.userPools = []
        let missing = try await fixture.service.fetchUserPool(assetIdPair: fixture.assetPair, accountId: Data())
        XCTAssertNil(missing)
        for values in [[], fixture.storage.values + fixture.storage.values] {
            fixture.storage.values = values
            do {
                _ = try await fixture.service.subscribePoolReserves(assetIdPair: fixture.assetPair)
                XCTFail("Missing and duplicate reserves must fail")
            } catch { XCTAssertTrue(error is PoolXykStorageError) }
        }
    }

    func testAPYFilteringAndStorageErrorsPropagate() async throws {
        let fixture = try CovDPoolHarness()
        for await response in try await fixture.service.subscribePoolsAPY(poolIds: ["unrelated"]) {
            XCTAssertTrue(response.isEmpty)
        }
        fixture.storage.error = CovDTestError.offline
        do {
            _ = try await fixture.service.fetchTotalIssuance(reservesId: fixture.reserveId)
            XCTFail("Expected storage error")
        } catch { XCTAssertEqual(error as? CovDTestError, .offline) }
        fixture.upstream.error = CovDTestError.offline
        do {
            _ = try await fixture.service.subscribeAvailablePools()
            XCTFail("Expected upstream error")
        } catch { XCTAssertEqual(error as? CovDTestError, .offline) }
    }
}
