import Foundation
import SSFPolkaswap
import SSFPools
import XCTest

@testable import fearless

final class CovDPoolListInteractorTests: XCTestCase {
    func testDetailsDeliversExactPoolPositionReservesAndAPY() throws {
        let fixture = try CovDPoolHarness()
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolDetailsInteractor(
            assetIdPair: fixture.assetPair, chain: fixture.chain, wallet: CovDFixtures.wallet(), liquidityPoolService: fixture.service
        )
        interactor.setup(with: output)
        XCTAssertTrue(CovDFixtures.spin { !output.pairs.isEmpty && !output.users.isEmpty && !output.reserves.isEmpty && !output.apys.isEmpty })
        XCTAssertEqual(output.pairs.first??.first?.pairId, fixture.pair.pairId)
        XCTAssertEqual(output.users.first??.first?.targetAssetPooled, 8)
        XCTAssertEqual(output.reserves.first??.reserves.fee, 200)
        XCTAssertEqual(output.apys.first?.first?.apy, 12)
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testDetailsReportsIndependentDataFailuresAndInvalidReserveAddress() throws {
        let fixture = try CovDPoolHarness()
        fixture.upstream.error = CovDTestError.offline
        fixture.storage.error = CovDTestError.offline
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolDetailsInteractor(
            assetIdPair: fixture.assetPair, chain: fixture.chain, wallet: CovDFixtures.wallet(), liquidityPoolService: fixture.service
        )
        interactor.setup(with: output)
        interactor.fetchApy(reservesId: "not-hex")
        XCTAssertTrue(CovDFixtures.spin { output.errors.count == 4 })
        XCTAssertEqual(Set(output.errors.keys), ["pairs", "users", "reserves", "apy"])
        XCTAssertEqual(output.errors["pairs"]?.first as? CovDTestError, .offline)
        fixture.upstream.error = nil
        fixture.storage.error = nil
        let watchOutput = CovDPoolOutputSpy()
        let watch = LiquidityPoolDetailsInteractor(
            assetIdPair: fixture.assetPair, chain: fixture.chain, wallet: CovDFixtures.wallet(substrate: false), liquidityPoolService: fixture.service
        )
        watch.setup(with: watchOutput)
        XCTAssertTrue(watchOutput.errors["users"]?.first is ChainAccountFetchingError)
        XCTAssertTrue(CovDFixtures.spin { !watchOutput.apys.isEmpty && !watchOutput.reserves.isEmpty })
    }

    func testAvailableListDeliversPoolsReservesAndDeduplicatesAPY() throws {
        let fixture = try CovDPoolHarness()
        let output = CovDPoolOutputSpy()
        let interactor = AvailableLiquidityPoolsListInteractor(liquidityPoolService: fixture.service, chain: fixture.chain)
        interactor.setup(with: output)
        interactor.fetchPools()
        XCTAssertTrue(CovDFixtures.spin { !output.pairs.isEmpty && !output.reserves.isEmpty && !output.apys.isEmpty })
        XCTAssertEqual(output.pairs.first??.first?.pairId, fixture.pair.pairId)
        XCTAssertEqual(output.reserves.first??.reserves.reserves, 100)
        XCTAssertEqual(output.apys.first?.first?.apy, 12)
        interactor.fetchApy(pools: fixture.upstream.pools)
        interactor.cancelTasks()
        XCTAssertEqual(output.apys.count, 1)
    }

    func testAvailableListReportsEachBackendFailure() throws {
        let fixture = try CovDPoolHarness()
        let output = CovDPoolOutputSpy()
        let interactor = AvailableLiquidityPoolsListInteractor(liquidityPoolService: fixture.service, chain: fixture.chain)
        interactor.setup(with: output)
        fixture.upstream.error = CovDTestError.offline
        interactor.fetchPools()
        interactor.fetchApy(pools: fixture.upstream.pools)
        XCTAssertTrue(CovDFixtures.spin { output.errors.count == 2 })
        XCTAssertEqual(Set(output.errors.keys), ["pairs", "apy"])
        fixture.upstream.error = nil
        fixture.storage.error = CovDTestError.offline
        interactor.fetchPools()
        XCTAssertTrue(CovDFixtures.spin { output.errors["reserves"] != nil && !output.apys.isEmpty })
        XCTAssertEqual(output.errors["reserves"]?.first as? CovDTestError, .offline)
        interactor.cancelTasks()
    }

    func testUserListDeliversPositionsAndAPYThenReportsFailure() throws {
        let fixture = try CovDPoolHarness()
        let output = CovDPoolOutputSpy()
        let interactor = UserLiquidityPoolsListInteractor(
            liquidityPoolService: fixture.service, chain: fixture.chain, wallet: CovDFixtures.wallet()
        )
        interactor.setup(with: output)
        interactor.fetchPools()
        XCTAssertTrue(CovDFixtures.spin { !output.users.isEmpty && !output.apys.isEmpty })
        XCTAssertEqual(output.users.first??.first?.accountPoolShare, 0.25)
        XCTAssertEqual(output.apys.first?.first?.apy, 12)
        interactor.fetchApy(pools: fixture.upstream.userPools)
        XCTAssertEqual(output.apys.count, 1)
        fixture.upstream.error = CovDTestError.offline
        interactor.fetchPools()
        XCTAssertTrue(CovDFixtures.spin { output.errors["pairs"] != nil })
        XCTAssertEqual(output.errors["pairs"]?.first as? CovDTestError, .offline)
        interactor.cancelTasks()
    }

    func testUserListRequiresAnAccountAndReportsAPYFailure() throws {
        let fixture = try CovDPoolHarness()
        let output = CovDPoolOutputSpy()
        let interactor = UserLiquidityPoolsListInteractor(
            liquidityPoolService: fixture.service, chain: fixture.chain, wallet: CovDFixtures.wallet(substrate: false)
        )
        interactor.setup(with: output)
        interactor.fetchPools()
        XCTAssertTrue(output.errors["pairs"]?.first is ChainAccountFetchingError)
        fixture.upstream.error = CovDTestError.offline
        interactor.fetchApy(pools: fixture.upstream.userPools)
        XCTAssertTrue(CovDFixtures.spin { output.errors["apy"] != nil })
        XCTAssertEqual(output.errors["apy"]?.first as? CovDTestError, .offline)
        interactor.cancelTasks()
    }
}
