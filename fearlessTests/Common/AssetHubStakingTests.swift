import XCTest
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import BigInt
@testable import fearless

final class AssetHubStakingTests: XCTestCase {
    func testAllThreeRoutesMatchExactGenesisAndNativeAsset() throws {
        for route in AssetHubStakingRoute.routes {
            XCTAssertEqual(AssetHubStakingRoute.staking(on: route.stakingChainId), route)
            XCTAssertEqual(AssetHubStakingRoute.migrating(route.relayChainId), route)
            XCTAssertNil(AssetHubStakingRoute.staking(on: route.relayChainId))
            XCTAssertNil(AssetHubStakingRoute.migrating(route.stakingChainId))
            XCTAssertTrue(NetworkRetirement.assetHubMigratedRelayChainIds.contains(route.relayChainId))

            let catalog = NetworkRetirement.applying(to: [hub(route), relay(route)])
            let selected = try XCTUnwrap(AssetHubStakingRoute.selectedAsset(
                ChainAssetId(chainId: route.relayChainId, assetId: route.nativeAssetId), in: catalog
            ))
            XCTAssertEqual(selected.chain.chainId, route.stakingChainId)
            XCTAssertEqual(selected.asset.id, route.nativeAssetId)
            XCTAssertEqual(selected.asset.staking, .assetHub)
            XCTAssertEqual(selected.stakingType, .relaychain)
            XCTAssertEqual(selected.chain.parentId, route.relayChainId)
            XCTAssertNil(catalog.first(where: { $0.chainId == route.relayChainId })?.assets.first?.staking)
            XCTAssertEqual(NetworkRetirement.applying(to: catalog), catalog)
        }
    }

    func testHubKeepsOnlyNativeDirectStakingAndNoPoolsOrCrowdloans() throws {
        let route = AssetHubStakingRoute.routes[0]
        let stablecoin = AssetModel(
            id: "usdt", name: "usdt", symbol: "usdt", precision: 6, isUtility: false, isNative: false,
            staking: .relayChain, type: .assets
        )
        let listed = hub(route, extraAssets: [stablecoin], options: [.poolStaking, .crowdloans, .utilityFeePayment])
        let offered = try XCTUnwrap(NetworkRetirement.offered(listed))
        XCTAssertEqual(offered.assets.first(where: { $0.id == route.nativeAssetId })?.staking, .assetHub)
        XCTAssertNil(offered.assets.first(where: { $0.id == "usdt" })?.staking)
        XCTAssertEqual(offered.options, [.utilityFeePayment])
        XCTAssertEqual(NetworkRetirement.storedUpdates(for: [listed]), [offered])
        XCTAssertEqual(NetworkRetirement.storedUpdates(for: [offered]), [])

        XCTAssertNil(NetworkRetirement.offered(hub(route, staking: .paraChain))?.assets.first?.staking)
        XCTAssertNil(
            NetworkRetirement.offered(hub(route, staking: .relayChain))?.assets.first?.staking,
            "Relay staking code never runs against a hub"
        )
        XCTAssertNil(NetworkRetirement.offered(hub(route, type: .assets))?.assets.first?.staking)
    }

    func testNamesSymbolsAndWrongParentCannotGrantStaking() throws {
        let route = AssetHubStakingRoute.routes[0]
        let catalog = NetworkRetirement.applying(to: [hub(route, parent: "unrelated")])
        XCTAssertNil(catalog.first?.assets.first?.staking)
        XCTAssertNil(AssetHubStakingRoute.staking(on: "Polkadot AssetHub"))
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(
            ChainAssetId(chainId: route.stakingChainId, assetId: route.nativeAssetId), in: catalog
        ))
        let other = AssetHubTestSupport.makeAsset(chainId: "other", assetId: route.nativeAssetId).chain
        XCTAssertEqual(NetworkRetirement.offered(other), other, "Chains outside the routes are unchanged")
    }

    func testSavedRelaySelectionDoesNotFallbackWhenHubMissingDisabledOrAssetWrong() throws {
        let route = AssetHubStakingRoute.routes[0]
        let relayOnly = NetworkRetirement.applying(to: [relay(route)])
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(
            ChainAssetId(chainId: route.relayChainId, assetId: route.nativeAssetId), in: relayOnly
        ))
        let catalog = NetworkRetirement.applying(to: [hub(route), relay(route)])
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(
            ChainAssetId(chainId: route.relayChainId, assetId: "unrelated-token"), in: catalog
        ))
        let disabled = catalog.map { $0.chainId == route.stakingChainId ? $0.replacingDisabled(true) : $0 }
        XCTAssertNil(AssetHubStakingRoute.selectedAsset(
            ChainAssetId(chainId: route.relayChainId, assetId: route.nativeAssetId), in: disabled
        ))
        let other = AssetHubTestSupport.makeAsset(chainId: "other")
        XCTAssertEqual(
            AssetHubStakingRoute.selectedAsset(other.chainAssetId, in: [other.chain])?.chainAssetId,
            other.chainAssetId,
            "A saved staking asset outside the routes is kept"
        )
    }

    func testAssetHubValueIsRelayTypeStakingAndUnknownValuesDecodeToNoStaking() throws {
        func decode(_ staking: String) throws -> AssetModel {
            let json = "{\"id\":\"a\",\"name\":\"a\",\"symbol\":\"a\",\"precision\":10,\"staking\":\"\(staking)\"}"
            return try JSONDecoder().decode(AssetModel.self, from: Data(json.utf8))
        }
        XCTAssertEqual(try decode("assetHub").staking, .assetHub)
        XCTAssertEqual(try decode("relaychain").staking, .relayChain)
        XCTAssertNil(try decode("futureStakingKind").staking, "A value a build does not know means no staking")
        XCTAssertEqual(StakingType(rawStakingType: .assetHub), .relaychain)
        XCTAssertTrue(RawStakingType.assetHub.isRelaychain)
    }

    func testAssetHubStakingOutsideTheRoutesIsDropped() throws {
        let asset = AssetModel(
            id: "native", name: "native", symbol: "N", precision: 10, isUtility: true, isNative: true, staking: .assetHub
        )
        let kept = AssetModel(
            id: "other", name: "other", symbol: "O", precision: 10, isUtility: false, isNative: false, staking: .relayChain
        )
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "unrelated", paraId: nil, name: "Other", assets: [asset, kept], xcm: nil,
            nodes: [], addressPrefix: 42, icon: nil, options: [.poolStaking], iosMinAppVersion: nil, identityChain: nil
        )
        let offered = try XCTUnwrap(NetworkRetirement.offered(chain))
        XCTAssertNil(offered.assets.first(where: { $0.id == "native" })?.staking)
        XCTAssertEqual(offered.assets.first(where: { $0.id == "other" })?.staking, .relayChain)
        XCTAssertEqual(offered.options, [.poolStaking], "Only the misplaced value is dropped")
    }

    func testDurationUsesHubSessionsAndBondingButRelayBabeClock() throws {
        let route = AssetHubStakingRoute.routes[0]
        let hub = try AssetHubIdentifiedRuntime(chainId: route.stakingChainId, values: [.eraLength: 6, .lockUpPeriod: 28])
        let relay = try StakingConstantRuntime(values: [.sessionLength: 2400, .babeBlockTime: 6000])
        var queried: [String] = []
        let clock = StakingRuntimeClock(runtime: { queried.append($0); return relay }, connection: { _ in nil })
        let result = try AssetHubTestSupport.execute(
            StakingDurationOperationFactory(clock: clock).createDurationOperation(from: hub)
        )
        XCTAssertEqual(queried, [route.relayChainId])
        XCTAssertEqual(result.session, 14400)
        XCTAssertEqual(result.era, 86400)
        XCTAssertEqual(result.unlocking, 2_419_200)
    }

    func testDurationFailsWithoutAssociatedRelayRuntime() throws {
        let hub = try AssetHubIdentifiedRuntime(chainId: AssetHubStakingRoute.routes[1].stakingChainId)
        let factory = StakingDurationOperationFactory(clock: StakingRuntimeClock(runtime: { _ in nil }))
        XCTAssertThrowsError(try AssetHubTestSupport.execute(factory.createDurationOperation(from: hub)))
    }

    func testLegacyClockKeepsOriginalRuntimeAndConnection() throws {
        let runtime = try StakingConstantRuntime()
        let connection = MockConnection()
        let clock = StakingRuntimeClock(runtime: { _ in XCTFail("Legacy must not resolve another runtime"); return nil })
        XCTAssertTrue(try clock.runtime(for: runtime) as AnyObject === runtime)
        XCTAssertTrue(try clock.connection(for: runtime, stakingConnection: connection) === connection)
    }

    func testAssetHubClockRequiresRelayConnection() throws {
        let hub = try AssetHubIdentifiedRuntime(chainId: AssetHubStakingRoute.routes[0].stakingChainId)
        let connection = MockConnection()
        XCTAssertThrowsError(try StakingRuntimeClock(connection: { _ in nil }).connection(for: hub, stakingConnection: connection))
        XCTAssertTrue(try StakingRuntimeClock(connection: { _ in connection }).connection(for: hub, stakingConnection: MockConnection()) === connection)
    }

    func testBondedEraTupleRejectsMalformedAndExtraValues() throws {
        let value = try JSONDecoder().decode(BondedEra.self, from: Data("[\"10\",\"60\"]".utf8))
        XCTAssertEqual(value.era, 10)
        XCTAssertEqual(value.session, 60)
        for json in ["[]", "[\"10\"]", "[\"10\",\"60\",\"99\"]", "[\"bad\",\"60\"]"] {
            XCTAssertThrowsError(try JSONDecoder().decode(BondedEra.self, from: Data(json.utf8)))
        }
    }

    func testModernLedgerWithoutLegacyRewardsPreservesBalancesAndUnlocks() throws {
        let ledger = try decodeLedger(extra: "")
        XCTAssertEqual(ledger.total, 1000)
        XCTAssertEqual(ledger.active, 800)
        XCTAssertEqual(ledger.unlocking, [UnlockChunk(value: 200, era: 12)])
        XCTAssertTrue(ledger.claimedRewards.isEmpty)
        XCTAssertEqual(ledger.redeemable(inEra: 12), 200)
        XCTAssertEqual(ledger.unbonding(inEra: 11), 200)
    }

    func testPresentMalformedRewardsCannotBeMistakenForAbsentModernField() throws {
        XCTAssertThrowsError(try decodeLedger(extra: ",\"claimedRewards\":\"bad\""))
        XCTAssertThrowsError(try decodeLedger(extra: ",\"legacyClaimedRewards\":null"))
        XCTAssertEqual(try decodeLedger(extra: ",\"claimedRewards\":[\"9\"]").claimedRewards.map(\.value), [9])
        XCTAssertEqual(try decodeLedger(extra: ",\"legacyClaimedRewards\":[\"8\"]").claimedRewards.map(\.value), [8])
    }

    func testObservedRewardsUseActualPointsCommissionAmountAndEraDuration() throws {
        let engine = try rewardEngine()
        let id = AssetHubTestSupport.first
        XCTAssertEqual(try engine.calculateEarnings(amount: 100, validatorAccountId: id, isCompound: false, period: .day), 8)
        XCTAssertEqual(engine.calculateAvgEarnings(amount: 100, isCompound: false, period: .day), 6)
        XCTAssertEqual(engine.calculateMaxEarnings(amount: 100, isCompound: false, period: .day), 8)
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .day, type: .max(id)), Decimal(string: "0.08"))
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .day, type: .max()), Decimal(string: "0.08"))
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .day, type: .avg), Decimal(string: "0.06"))
        XCTAssertEqual(engine.rewardAssetRate, 1)
        XCTAssertFalse(engine.avgEarningTitle(locale: Locale(identifier: "en")).isEmpty)
        XCTAssertFalse(engine.maxEarningsTitle(locale: Locale(identifier: "en")).isEmpty)
    }

    func testRewardCompoundingAndZeroAmountDoNotInventReward() throws {
        let engine = try rewardEngine()
        XCTAssertEqual(NSDecimalNumber(decimal: engine.calculateMaxEarnings(amount: 100, isCompound: true, period: .custom(days: 2))).doubleValue, 16.64, accuracy: 0.00001)
        XCTAssertEqual(engine.calculateAvgEarnings(amount: 0, isCompound: true, period: .year), 0)
        XCTAssertEqual(engine.calculateMaxEarnings(amount: 1, isCompound: false, period: .custom(days: -1)), 0)
        XCTAssertThrowsError(try engine.calculateEarnings(amount: 1, validatorAccountId: Data(), isCompound: false, period: .day))
    }

    func testInvalidRewardEvidenceFailsInsteadOfUsingInflationFallback() throws {
        for duration in [0.0, -.infinity, .nan] { XCTAssertThrowsError(try rewardEngine(duration: duration)) }
        XCTAssertThrowsError(try rewardEngine(totalPoints: 0))
        XCTAssertThrowsError(try rewardEngine(totalPoints: 4))
    }

    private func hub(
        _ route: AssetHubStakingRoute,
        parent: String? = nil,
        staking: RawStakingType = .assetHub,
        type: SubstrateAssetType = .normal,
        extraAssets: [AssetModel] = [],
        options: [ChainOptions]? = [.utilityFeePayment]
    ) -> ChainModel {
        let native = AssetModel(
            id: route.nativeAssetId, name: "native", symbol: "N", precision: 10,
            isUtility: true, isNative: false, staking: staking, type: type
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: route.stakingChainId, parentId: parent ?? route.relayChainId,
            paraId: "1000", name: "Asset Hub", assets: Set([native] + extraAssets), xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://example.com")!, name: "test", apikey: nil)],
            addressPrefix: 0, icon: nil, options: options, iosMinAppVersion: nil, identityChain: nil
        )
    }

    private func relay(_ route: AssetHubStakingRoute) -> ChainModel {
        let native = AssetModel(
            id: route.nativeAssetId, name: "native", symbol: "N", precision: 10,
            isUtility: true, isNative: false, staking: .relayChain, type: .normal
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: route.relayChainId, paraId: nil, name: "Relay",
            assets: [native], xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://example.com")!, name: "test", apikey: nil)],
            addressPrefix: 0, icon: nil, options: [.poolStaking, .crowdloans], iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func decodeLedger(extra: String) throws -> StakingLedger {
        try JSONDecoder().decode(StakingLedger.self, from: Data(("{\"stash\":\"" + Data(repeating: 1, count: 32).base64EncodedString() + "\",\"total\":\"1000\",\"active\":\"800\",\"unlocking\":[{\"era\":\"12\",\"value\":\"200\"}]" + extra + "}").utf8))
    }

    private func rewardEngine(duration: Double = 86400, totalPoints: UInt32 = 3) throws -> AssetHubRewardCalculatorEngine {
        let first = AssetHubTestSupport.first
        let second = AssetHubTestSupport.second
        let points = try JSONDecoder().decode(EraRewardPoints.self, from: JSONSerialization.data(withJSONObject: [
            "total": String(totalPoints), "individual": [[first.base64EncodedString(), "2"], [second.base64EncodedString(), "1"]]
        ]))
        return try AssetHubRewardCalculatorEngine(reward: 45, points: points, validators: [
            AssetHubTestSupport.validator(first), AssetHubTestSupport.validator(second)
        ], eraDuration: duration)
    }
}

final class AssetHubIdentifiedRuntime: RuntimeCodingServiceProtocol, StakingRuntimeIdentifying {
    let chainId: String
    let base: StakingConstantRuntime
    var snapshot: RuntimeSnapshot? { base.snapshot }
    init(chainId: String, values: [fearless.ConstantCodingPath: UInt32] = StakingConstantRuntime.defaults) throws {
        self.chainId = chainId
        base = try StakingConstantRuntime(values: values)
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { base.fetchCoderFactoryOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { try await base.fetchCoderFactory() }
}
