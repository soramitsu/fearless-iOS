import BigInt
import Foundation
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFStorageQueryKit
import XCTest

@testable import fearless

final class CovDPoolOperationStub: PoolsOperationService {
    var error: Error?
    var estimates: [PoolOperation] = []
    var submissions: [PoolOperation] = []

    func estimateFee(liquidityOperation: PoolOperation) async throws -> BigUInt {
        estimates.append(liquidityOperation)
        if let error { throw error }
        return 17
    }

    func submit(liquidityOperation: PoolOperation) async throws -> String {
        submissions.append(liquidityOperation)
        if let error { throw error }
        return "0xsubmitted"
    }
}

final class CovDAccountSubscriptionSpy: AccountInfoSubscriptionAdapterProtocol {
    var subscribed: [ChainAsset] = []
    weak var handler: AccountInfoSubscriptionAdapterHandler?

    func subscribe(
        chainAsset: ChainAsset, accountId _: AccountId, handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool
    ) {
        subscribed.append(chainAsset)
        self.handler = handler
    }

    func subscribe(
        chainsAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool
    ) {
        subscribed += chainsAssets
        self.handler = handler
    }

    func reset() { subscribed = [] }
    func unsubscribe(chainAsset: ChainAsset) { subscribed.removeAll { $0.chainAssetId == chainAsset.chainAssetId } }
    func update(wallet _: MetaAccountModel) {}
}

final class CovDPoolOutputSpy: LiquidityPoolSupplyInteractorOutput, LiquidityPoolSupplyConfirmInteractorOutput,
    LiquidityPoolRemoveLiquidityInteractorOutput, LiquidityPoolDetailsInteractorOutput,
    AvailableLiquidityPoolsListInteractorOutput, UserLiquidityPoolsListInteractorOutput {
    var fees: [BigUInt] = []
    var hashes: [String] = []
    var pairs: [[LiquidityPair]?] = []
    var users: [[AccountPool]?] = []
    var reserves: [PolkaswapPoolReservesInfo?] = []
    var apys: [[PoolApyInfo]] = []
    var issuances: [BigUInt?] = []
    var accounts: [ChainAssetId] = []
    private let errorLock = NSLock()
    private var recordedErrors: [String: [Error]] = [:]
    var errors: [String: [Error]] {
        errorLock.lock()
        defer { errorLock.unlock() }
        return recordedErrors
    }

    private func record(_ error: Error, for key: String) {
        errorLock.lock()
        defer { errorLock.unlock() }
        recordedErrors[key, default: []].append(error)
    }

    func didReceiveFee(_ fee: BigUInt) { fees.append(fee) }
    func didReceiveTransactionHash(_ hash: String) { hashes.append(hash) }
    func didReceiveLiquidityPairs(pairs: [LiquidityPair]?) { self.pairs.append(pairs) }
    func didReceiveLiquidityPairs(pools: [LiquidityPair]?) { pairs.append(pools) }
    func didReceiveLiquidityPair(liquidityPair: LiquidityPair?) { pairs.append(liquidityPair.map { [$0] }) }
    func didReceiveUserPools(accountPools: [AccountPool]?) { users.append(accountPools) }
    func didReceiveUserPool(pool: AccountPool?) { users.append(pool.map { [$0] }) }
    func didReceivePoolReserves(reserves: PolkaswapPoolReservesInfo?) { self.reserves.append(reserves) }
    func didReceivePoolReserves(reserves: CachedStorageResponse<PolkaswapPoolReservesInfo>?) { self.reserves.append(reserves?.value) }
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>) {
        self.reserves += reserves.value?.map { Optional($0) } ?? []
    }
    func didReceivePoolsReserves(reserves: CachedStorageResponse<[PolkaswapPoolReservesInfo]>?) {
        self.reserves += reserves?.value?.map { Optional($0) } ?? []
    }
    func didReceivePoolAPY(apyInfo: PoolApyInfo?) { apys.append(apyInfo.map { [$0] } ?? []) }
    func didReceivePoolAPY(apy: PoolApyInfo?) { apys.append(apy.map { [$0] } ?? []) }
    func didReceivePoolsAPY(apy: [PoolApyInfo]?) { apys.append(apy ?? []) }
    func didReceivePoolsAPY(apy: [PoolApyInfo]) { apys.append(apy) }
    func didReceiveTotalIssuance(totalIssuance: BigUInt?) { issuances.append(totalIssuance) }
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) { accounts.append(chainAsset.chainAssetId) }
    func didReceiveFeeError(_ error: Error) { record(error, for: "fee") }
    func didReceiveSubmitError(error: Error) { record(error, for: "submit") }
    func didReceivePoolApyError(error: Error) { record(error, for: "apy") }
    func didReceivePoolsApyError(error: Error) { record(error, for: "apy") }
    func didReceivePoolReservesError(error: Error) { record(error, for: "reserves") }
    func didReceivePoolsReservesError(error: Error) { record(error, for: "reserves") }
    func didReceiveLiquidityPairError(error: Error) { record(error, for: "pairs") }
    func didReceiveLiquidityPairsError(error: Error) { record(error, for: "pairs") }
    func didReceiveUserPoolError(error: Error) { record(error, for: "users") }
    func didReceiveUserPoolsError(error: Error) { record(error, for: "users") }
    func didReceiveTotalIssuanceError(error: Error) { record(error, for: "issuance") }
}

final class CovDPoolInteractorTests: XCTestCase {
    override func tearDown() {
        MultiChainFeaturePolicy.update(.defaultConfig)
        super.tearDown()
    }

    func testSupplyDeliversPoolsReservesAPYBalancesAndBothFeeResults() throws {
        let fixture = try CovDPoolHarness()
        let operation = CovDPoolOperationStub()
        let adapter = CovDAccountSubscriptionSpy()
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolSupplyInteractor(
            lpOperationService: operation, lpDataService: fixture.service, liquidityPair: fixture.pair,
            chain: fixture.chain, accountInfoSubscriptionAdapter: adapter
        )
        interactor.setup(with: output)
        interactor.fetchPools()
        interactor.estimateFee(supplyLiquidityInfo: fixture.supply)
        XCTAssertTrue(CovDFixtures.spin { !output.fees.isEmpty && !output.pairs.isEmpty && !output.apys.isEmpty && !output.reserves.isEmpty })
        XCTAssertEqual(output.fees, [17])
        XCTAssertEqual(output.pairs.first??.first?.pairId, fixture.pair.pairId)
        XCTAssertEqual(output.apys.first?.first?.apy, 12)
        XCTAssertEqual(output.reserves.first??.reserves.fee, 200)
        XCTAssertEqual(Set(adapter.subscribed.map(\.chainAssetId)), Set(fixture.chain.chainAssets.map(\.chainAssetId)))
        let asset = try XCTUnwrap(adapter.subscribed.first)
        adapter.handler?.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: asset)
        XCTAssertEqual(output.accounts, [asset.chainAssetId])
        operation.error = CovDTestError.offline
        interactor.estimateFee(supplyLiquidityInfo: fixture.supply)
        XCTAssertTrue(CovDFixtures.spin { output.errors["fee"]?.count == 1 })
        XCTAssertEqual(output.errors["fee"]?.first as? CovDTestError, .offline)
        guard case let .substrateSupplyLiquidity(model) = operation.estimates.first else { return XCTFail("Expected supply fee") }
        XCTAssertEqual(model.baseAssetAmount, 1)
    }

    func testSupplyErrorsReachTheirMatchingCallbacks() throws {
        let fixture = try CovDPoolHarness()
        fixture.storage.error = CovDTestError.offline
        fixture.upstream.error = CovDTestError.offline
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolSupplyInteractor(
            lpOperationService: CovDPoolOperationStub(), lpDataService: fixture.service, liquidityPair: fixture.pair,
            chain: fixture.chain, accountInfoSubscriptionAdapter: CovDAccountSubscriptionSpy()
        )
        interactor.setup(with: output)
        interactor.fetchPools()
        XCTAssertTrue(CovDFixtures.spin { output.errors.count == 3 })
        XCTAssertEqual(Set(output.errors.keys), ["apy", "reserves", "pairs"])
        XCTAssertTrue(output.errors.values.allSatisfy { $0.first as? CovDTestError == .offline })
    }

    func testSupplyConfirmationForwardsFeesSubmissionAndRemotePause() throws {
        let fixture = try CovDPoolHarness()
        let operation = CovDPoolOperationStub()
        let adapter = CovDAccountSubscriptionSpy()
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolSupplyConfirmInteractor(
            lpOperationService: operation, lpDataService: fixture.service, liquidityPair: fixture.pair,
            chain: fixture.chain, accountInfoSubscriptionAdapter: adapter
        )
        interactor.setup(with: output)
        interactor.estimateFee(supplyLiquidityInfo: fixture.supply)
        XCTAssertTrue(CovDFixtures.spin { !output.fees.isEmpty && !output.apys.isEmpty })
        XCTAssertEqual(output.apys.first?.first?.apy, 12)
        XCTAssertEqual(output.fees, [17])
        let asset = try XCTUnwrap(adapter.subscribed.first)
        adapter.handler?.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: asset)
        XCTAssertEqual(output.accounts, [asset.chainAssetId])
        MultiChainFeaturePolicy.update(FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, polkaswapMutationsEnabled: true))
        interactor.submit(supplyLiquidityInfo: fixture.supply)
        XCTAssertTrue(CovDFixtures.spin { output.hashes == ["0xsubmitted"] })
        operation.error = CovDTestError.offline
        fixture.upstream.error = CovDTestError.offline
        interactor.estimateFee(supplyLiquidityInfo: fixture.supply)
        interactor.fetchApy()
        interactor.submit(supplyLiquidityInfo: fixture.supply)
        XCTAssertTrue(CovDFixtures.spin { output.errors.count == 3 })
        XCTAssertEqual(Set(output.errors.keys), ["fee", "submit", "apy"])
        MultiChainFeaturePolicy.update(FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, polkaswapMutationsEnabled: false))
        interactor.submit(supplyLiquidityInfo: fixture.supply)
        XCTAssertEqual(operation.submissions.count, 2)
        XCTAssertTrue(output.errors["submit"]?.last?.localizedDescription.contains("disabled") == true)
    }

    func testRemovalDeliversPositionIssuanceReservesFeesAndSubmission() throws {
        let fixture = try CovDPoolHarness()
        let operation = CovDPoolOperationStub()
        let adapter = CovDAccountSubscriptionSpy()
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolRemoveLiquidityInteractor(
            lpOperationService: operation, lpDataService: fixture.service, liquidityPair: fixture.pair,
            chain: fixture.chain, accountInfoSubscriptionAdapter: adapter, wallet: CovDFixtures.wallet()
        )
        interactor.setup(with: output)
        interactor.estimateFee(removeLiquidityInfo: fixture.removal)
        XCTAssertTrue(CovDFixtures.spin { !output.fees.isEmpty && !output.users.isEmpty && !output.reserves.isEmpty && !output.issuances.isEmpty })
        XCTAssertEqual(output.users.first??.first?.baseAssetPooled, 4)
        XCTAssertEqual(output.issuances.first ?? nil, 500)
        XCTAssertEqual(output.reserves.first??.reserves.reserves, 100)
        XCTAssertEqual(output.fees, [17])
        let asset = try XCTUnwrap(adapter.subscribed.first)
        adapter.handler?.handleAccountInfo(result: .failure(CovDTestError.offline), accountId: Data(), chainAsset: asset)
        XCTAssertEqual(output.accounts, [asset.chainAssetId])
        MultiChainFeaturePolicy.update(FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, polkaswapMutationsEnabled: true))
        interactor.submit(removeLiquidityInfo: fixture.removal)
        XCTAssertTrue(CovDFixtures.spin { output.hashes == ["0xsubmitted"] })
        operation.error = CovDTestError.offline
        interactor.estimateFee(removeLiquidityInfo: fixture.removal)
        interactor.submit(removeLiquidityInfo: fixture.removal)
        XCTAssertTrue(CovDFixtures.spin { output.errors["fee"] != nil && output.errors["submit"] != nil })
        XCTAssertEqual(output.errors["submit"]?.first as? CovDTestError, .offline)
        MultiChainFeaturePolicy.update(FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, polkaswapMutationsEnabled: false))
        interactor.submit(removeLiquidityInfo: fixture.removal)
        XCTAssertEqual(operation.submissions.count, 2)
        XCTAssertTrue(output.errors["submit"]?.last?.localizedDescription.contains("disabled") == true)
    }

    func testRemovalReportsUnavailableStorageAndMissingAccount() throws {
        let fixture = try CovDPoolHarness()
        fixture.storage.error = CovDTestError.offline
        fixture.upstream.error = CovDTestError.offline
        let output = CovDPoolOutputSpy()
        let interactor = LiquidityPoolRemoveLiquidityInteractor(
            lpOperationService: CovDPoolOperationStub(), lpDataService: fixture.service, liquidityPair: fixture.pair,
            chain: fixture.chain, accountInfoSubscriptionAdapter: CovDAccountSubscriptionSpy(), wallet: CovDFixtures.wallet()
        )
        interactor.setup(with: output)
        XCTAssertTrue(CovDFixtures.spin { output.errors.count == 3 })
        XCTAssertEqual(Set(output.errors.keys), ["reserves", "users", "issuance"])
        let missingOutput = CovDPoolOutputSpy()
        let missing = LiquidityPoolRemoveLiquidityInteractor(
            lpOperationService: CovDPoolOperationStub(), lpDataService: fixture.service,
            liquidityPair: CovDLiquidityFixtures.pair(fixture.chain, reservesId: "not-hex"), chain: fixture.chain,
            accountInfoSubscriptionAdapter: CovDAccountSubscriptionSpy(), wallet: CovDFixtures.wallet(substrate: false)
        )
        missing.setup(with: missingOutput)
        XCTAssertTrue(CovDFixtures.spin { missingOutput.errors.count == 3 })
        XCTAssertTrue(missingOutput.errors["users"]?.first is ChainAccountFetchingError)
        XCTAssertTrue(missingOutput.errors["issuance"]?.first is CommonError)
    }
    func testSupplyConfirmationReportsApyErrorForNativeAvailablePoolAddressFormat() throws {
        let fixture = try CovDPoolHarness()
        let address = try fearless.AddressFactory.address(for: fixture.reserveId, chain: fixture.chain)
        let output = CovDPoolOutputSpy()
        let adapter = CovDAccountSubscriptionSpy()
        let interactor = LiquidityPoolSupplyConfirmInteractor(
            lpOperationService: CovDPoolOperationStub(), lpDataService: fixture.service,
            liquidityPair: CovDLiquidityFixtures.pair(fixture.chain, reservesId: address), chain: fixture.chain,
            accountInfoSubscriptionAdapter: adapter
        )
        interactor.setup(with: output)
        // The SS58 reserves id is decoded as hex, so the pool's indexed APY (12) is never delivered.
        XCTAssertTrue(CovDFixtures.spin { output.errors["apy"] != nil || !output.apys.isEmpty })
        XCTAssertFalse(output.apys.joined().contains { $0.apy == 12 })
        XCTAssertEqual(adapter.subscribed.count, fixture.chain.chainAssets.count)
    }

}
