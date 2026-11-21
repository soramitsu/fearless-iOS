import BigInt
import Foundation
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFStorageQueryKit
import SSFUtils
import XCTest
@testable import fearless

/// SORA pool reserves account ids reach the app as SS58 addresses (the available pools) or as hex (the user's
/// pools). The pool screens read every one as hex; an SS58 address read as hex does not fail but gives other
/// bytes, so the pool's APY was never found and the remove flow could not find the pool's total issuance.
final class LiquidityPoolReservesIdTests: XCTestCase {
    private let reservesAccountId = Data(repeating: 0x5A, count: 32)

    func testReservesIdIsReadFromAnAddressOrFromHex() throws {
        let chain = LiquidityPoolReservesIdFixtures.chain()
        let address = try AddressFactory.address(for: reservesAccountId, chain: chain)

        XCTAssertEqual(try LiquidityPoolReservesId.accountId(from: address, chain: chain), reservesAccountId)
        XCTAssertEqual(try LiquidityPoolReservesId.accountId(from: reservesAccountId.toHex(), chain: chain), reservesAccountId)
        XCTAssertEqual(
            try LiquidityPoolReservesId.accountId(from: reservesAccountId.toHex(includePrefix: true), chain: chain),
            reservesAccountId
        )
        XCTAssertEqual(try LiquidityPoolReservesId.address(from: address, chain: chain), address)
        XCTAssertEqual(try LiquidityPoolReservesId.address(from: reservesAccountId.toHex(), chain: chain), address)
    }

    func testSupplyConfirmationShowsTheApyOfAnAvailablePoolWithAnAddressReservesId() throws {
        let chain = LiquidityPoolReservesIdFixtures.chain()
        let address = try AddressFactory.address(for: reservesAccountId, chain: chain)
        let upstream = LiquidityPoolReservesIdUpstream()
        upstream.apys = [PoolApyInfo(poolId: address, apy: 12)]
        let service = fearless.PolkaswapLiquidityPoolService(
            upstream: upstream, poolStorage: LiquidityPoolReservesIdStorage(), chain: chain
        )
        let output = LiquidityPoolReservesIdSupplyOutput()
        let interactor = LiquidityPoolSupplyConfirmInteractor(
            lpOperationService: LiquidityPoolReservesIdOperations(),
            lpDataService: service,
            liquidityPair: LiquidityPoolReservesIdFixtures.pair(reservesId: address),
            chain: chain,
            accountInfoSubscriptionAdapter: LiquidityPoolReservesIdAccountInfo()
        )

        interactor.setup(with: output)

        let answered = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in output.apys.count + output.apyErrors.count > 0 }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [answered], timeout: 10), .completed)
        XCTAssertEqual(output.apyErrors.count, 0)
        XCTAssertEqual(output.apys.map { $0?.apy }, [12], "the pool's APY is found by its reserves address")
    }

    func testRemoveLiquidityReadsTheTotalIssuanceOfAnAvailablePoolWithAnAddressReservesId() async throws {
        let chain = LiquidityPoolReservesIdFixtures.chain()
        let address = try AddressFactory.address(for: reservesAccountId, chain: chain)
        let storage = LiquidityPoolReservesIdStorage()
        storage.issuance = [reservesAccountId: 500]
        let service = fearless.PolkaswapLiquidityPoolService(
            upstream: LiquidityPoolReservesIdUpstream(), poolStorage: storage, chain: chain
        )

        let accountId = try LiquidityPoolReservesId.accountId(from: address, chain: chain)
        let issuance = try await service.fetchTotalIssuance(reservesId: accountId)

        XCTAssertEqual(issuance, 500)
    }
}

// MARK: - Fixtures

enum LiquidityPoolReservesIdFixtures {
    static let xor = "0x0200000000000000000000000000000000000000000000000000000000000000"
    static let pswap = "0x0200050000000000000000000000000000000000000000000000000000000000"

    static func chain() -> ChainModel {
        let xor = AssetModel(
            id: "xor", name: "XOR", symbol: "XOR", precision: 18, currencyId: Self.xor,
            isUtility: true, isNative: true, staking: nil
        )
        let pswap = AssetModel(
            id: "pswap", name: "PSWAP", symbol: "PSWAP", precision: 18, currencyId: Self.pswap,
            isUtility: false, isNative: true, staking: nil
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: "sora-pool-reserves", parentId: nil, paraId: nil, name: "SORA Mainnet",
            assets: [xor, pswap], xcm: nil, nodes: [], addressPrefix: 69, icon: nil, iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func pair(reservesId: String) -> LiquidityPair {
        LiquidityPair(
            pairId: "\(xor)-\(pswap)",
            chainId: nil,
            baseAssetId: xor,
            targetAssetId: pswap,
            reservesId: reservesId
        )
    }
}

final class LiquidityPoolReservesIdUpstream: SSFPolkaswap.PolkaswapLiquidityPoolService {
    var apys: [PoolApyInfo] = []

    func fetchAvailablePools() async throws -> [LiquidityPair] { [] }
    func fetchUserPools(accountId _: Data) async throws -> [AccountPool] { [] }
    func fetchPoolsAPY() async throws -> [PoolApyInfo] { apys }
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

final class LiquidityPoolReservesIdStorage: PoolXykStorage {
    var issuance: TotalIssuanceByReservesId = [:]

    func totalIssuance(chain _: ChainModel) async throws -> TotalIssuanceByReservesId { issuance }
    func reserves(pairs _: [AssetIdPair], chain _: ChainModel) async throws -> [PolkaswapPoolReservesInfo] { [] }
    func accountPools(accountId _: Data, chain _: ChainModel) async throws -> [UserPool] { [] }
    func properties(pairs _: [AssetIdPair], chain _: ChainModel) async throws -> [AssetIdPair: LiquidityPoolProperties] { [:] }
    func properties(
        baseAssetIds _: [SSFPolkaswap.PolkaswapDexInfoAssetId], chain _: ChainModel
    ) async throws -> [AssetIdPair: LiquidityPoolProperties] { [:] }
    func poolProviders(
        properties _: [LiquidityPoolProperties], accountId _: Data, chain _: ChainModel
    ) async throws -> [PoolProvidersStorageKey: BigUInt] { [:] }

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

final class LiquidityPoolReservesIdOperations: PoolsOperationService {
    func submit(liquidityOperation _: PoolOperation) async throws -> String {
        throw NSError(domain: "pool-operations", code: 1)
    }

    func estimateFee(liquidityOperation _: PoolOperation) async throws -> BigUInt {
        throw NSError(domain: "pool-operations", code: 2)
    }
}

final class LiquidityPoolReservesIdAccountInfo: AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset _: ChainAsset,
        accountId _: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}

final class LiquidityPoolReservesIdSupplyOutput: LiquidityPoolSupplyConfirmInteractorOutput {
    private let lock = NSLock()
    private var receivedApys: [PoolApyInfo?] = []
    private var receivedApyErrors: [Error] = []

    var apys: [PoolApyInfo?] {
        lock.lock()
        defer { lock.unlock() }
        return receivedApys
    }

    var apyErrors: [Error] {
        lock.lock()
        defer { lock.unlock() }
        return receivedApyErrors
    }

    func didReceiveFee(_: BigUInt) {}
    func didReceiveFeeError(_: Error) {}
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {}

    func didReceivePoolAPY(apyInfo: PoolApyInfo?) {
        lock.lock()
        receivedApys.append(apyInfo)
        lock.unlock()
    }

    func didReceivePoolApyError(error: Error) {
        lock.lock()
        receivedApyErrors.append(error)
        lock.unlock()
    }

    func didReceiveTransactionHash(_: String) {}
    func didReceiveSubmitError(error _: Error) {}
}
