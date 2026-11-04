import XCTest
import SSFUtils
import SSFModels
import SSFRuntimeCodingService
import RobinHood
@testable import fearless

final class AssetHubOperationIntegrationTests: XCTestCase {
    func testPayoutDiscoveryReadsNominatedValidatorsAndFiltersClaimedHistoricalPages() async throws {
        let fixture = try AssetHubStorageFixture()
        let validator = Data(repeating: 1, count: 32)
        let nominator = Data(repeating: 2, count: 32)
        try baseEra(fixture, validator: validator)
        _ = try fixture.put(.erasStakersOverview, json: "{\"total\":\"300\",\"own\":\"100\",\"nominator_count\":\"1\",\"page_count\":\"1\"}", era: 10, account: validator)
        _ = try fixture.put(.nominators, json: "{\"targets\":[\"\(validator.toHex(includePrefix: true))\"],\"submitted_in\":\"9\",\"suppressed\":false}", account: nominator)
        let page = "{\"page_total\":\"200\",\"others\":[{\"who\":\"\(nominator.toHex(includePrefix: true))\",\"value\":\"200\"}]}"
        _ = try fixture.put(.erasStakersPaged, json: page, era: 11, account: validator, page: 0)
        _ = try fixture.put(.erasStakersPaged, json: page, era: 10, account: validator, page: 0)
        _ = try fixture.put(.claimedRewards, json: "[\"0\"]", era: 10, account: validator)
        let factory = AssetHubPayoutsOperationFactory(chain: try chain(fixture), account: nominator, runtime: fixture.runtime, engine: fixture)
        let result = try await run(factory.create())
        XCTAssertEqual(result.payouts.count, 1)
        let payout = try XCTUnwrap(result.payouts.first)
        XCTAssertEqual(payout.era, 11)
        XCTAssertEqual(payout.page, 0)
        XCTAssertEqual(payout.validator, validator)
        XCTAssertEqual(payout.reward, Decimal(string: "0.0000001601"))
        XCTAssertFalse(fixture.requests.contains { $0.0 == "state_getKeysPaged" }, "No exposure map is paged through")
    }

    func testPayoutDiscoveryDoesNotReadValidatorsTheAccountNoLongerNominates() async throws {
        let fixture = try AssetHubStorageFixture()
        let validator = Data(repeating: 1, count: 32)
        let nominator = Data(repeating: 2, count: 32)
        try baseEra(fixture, validator: validator)
        let page = "{\"page_total\":\"200\",\"others\":[{\"who\":\"\(nominator.toHex(includePrefix: true))\",\"value\":\"200\"}]}"
        _ = try fixture.put(.erasStakersPaged, json: page, era: 11, account: validator, page: 0)
        let factory = AssetHubPayoutsOperationFactory(chain: try chain(fixture), account: nominator, runtime: fixture.runtime, engine: fixture)
        let result = try await run(factory.create())
        XCTAssertTrue(result.payouts.isEmpty)
        XCTAssertFalse(fixture.requests.contains { $0.0 == "state_getKeysPaged" })
    }

    func testPayoutDiscoveryFailsWhenAnOverviewCountsAPageThatIsMissing() async throws {
        let fixture = try AssetHubStorageFixture()
        let validator = Data(repeating: 1, count: 32)
        let nominator = Data(repeating: 2, count: 32)
        try baseEra(fixture, validator: validator)
        _ = try fixture.put(.nominators, json: "{\"targets\":[\"\(validator.toHex(includePrefix: true))\"],\"submitted_in\":\"9\",\"suppressed\":false}", account: nominator)
        let factory = AssetHubPayoutsOperationFactory(chain: try chain(fixture), account: nominator, runtime: fixture.runtime, engine: fixture)
        do {
            _ = try await run(factory.create())
            XCTFail("A counted page without a value must not read as no reward")
        } catch {}
    }

    func testFormerValidatorVirtualPagePaysOrdinaryAndSeparateIncentiveWithoutCurrentRole() async throws {
        let fixture = try AssetHubStorageFixture()
        let validator = Data(repeating: 1, count: 32)
        try baseEra(fixture, validator: validator)
        _ = try fixture.put(.erasStakersOverview, json: "{\"total\":\"100\",\"own\":\"100\",\"nominator_count\":\"0\",\"page_count\":\"0\"}", era: 11, account: validator)
        _ = try fixture.put(.validatorIncentiveBudget, json: "\"1000\"", era: 11)
        _ = try fixture.put(.validatorIncentiveWeight, json: "\"4\"", era: 11, account: validator)
        _ = try fixture.put(.sumWeightedPoints, json: "\"12\"", era: 11)
        let factory = AssetHubPayoutsOperationFactory(chain: try chain(fixture), account: validator, runtime: fixture.runtime, engine: fixture)
        let result = try await run(factory.create())
        XCTAssertEqual(result.payouts.count, 1)
        XCTAssertEqual(result.payouts.first?.page, 0)
        XCTAssertEqual(result.payouts.first?.reward, Decimal(string: "0.0000004"))
    }

    func testValidatorSlashWarningsUsePostNominationEraAndFinalizedStorage() async throws {
        let fixture = try AssetHubStorageFixture()
        let first = Data(repeating: 1, count: 32)
        let second = Data(repeating: 2, count: 32)
        _ = try fixture.put(.validatorSlashInEra, json: "[\"1\",\"10\"]", era: 11, account: first)
        _ = try fixture.put(.validatorSlashInEra, json: "[\"1\",\"10\"]", era: 9, account: second)
        let result = try await run(AssetHubSlashesOperationFactory(engine: fixture, runtime: fixture.runtime).validatorSlashes(ids: [first, first, second], submittedIn: 10))
        XCTAssertEqual(result[first], true)
        XCTAssertEqual(result[second], false)
        XCTAssertEqual(result.count, 2)
    }

    func testModernUnappliedSlashesDecodeOneValuePerCompositeStorageKey() async throws {
        let fixture = try AssetHubStorageFixture()
        let account = Data(repeating: 1, count: 32)
        _ = try fixture.put(.unappliedSlashes, json: "{\"validator\":\"\(account.toHex(includePrefix: true))\",\"own\":\"100\",\"others\":[],\"reporter\":null,\"payout\":\"0\"}", era: 11, account: account, page: 0)
        let result = try await run(AssetHubSlashesOperationFactory(engine: fixture, runtime: fixture.runtime).unapplied())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.value?.count, 1)
        XCTAssertEqual(result.first?.value?.first?.validator, account)
    }

    func testColdRuntimeWithoutIdentityReturnsExplicitEmptyMapAndWithoutSlashingSpansReturnsNil() async throws {
        let fixture = try AssetHubStorageFixture(name: "westend")
        let runtime = RuntimeCodingServiceStub(factory: fixture.runtime.factory)
        XCTAssertNil(runtime.snapshot)
        let request = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let chain = try chain(fixture)
        let identities = try await run(IdentityOperationFactory(requestFactory: request).createIdentityWrapper(for: { [Data(repeating: 1, count: 32)] }, engine: fixture, runtimeService: runtime, chain: chain))
        XCTAssertTrue(identities.isEmpty)
        let asset = try XCTUnwrap(chain.assets.first)
        let spans = try await run(SlashesOperationFactory(storageRequestFactory: request).createSlashingSpansOperationForStash("unused", engine: fixture, runtimeService: runtime, chainAsset: ChainAsset(chain: chain, asset: asset)))
        XCTAssertNil(spans)
        XCTAssertTrue(fixture.requests.isEmpty, "Metadata proves these legacy pallets are absent")
    }

    func testUnbondingGraphCombinesNativeFastDurationWithActiveEraAccountHistory() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let account = Data(repeating: 3, count: 32)
        _ = try fixture.put(.activeEra, json: "{\"index\":\"100\",\"start\":null}")
        _ = try fixture.put(.currentEra, json: "\"101\"")
        _ = try fixture.put(.areNominatorsSlashable, json: "false")
        let factory = AssetHubUnbondingOperationFactory(storage: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager()), duration: FixedDuration())
        let fast = try await run(factory.create(accountId: account, runtime: fixture.runtime, connection: fixture))
        XCTAssertEqual(fast.unlocking, 172_800)
        _ = try fixture.put(.lastValidatorEra, json: "\"73\"", account: account)
        let full = try await run(factory.create(accountId: account, runtime: fixture.runtime, connection: fixture))
        XCTAssertEqual(full.unlocking, 2_419_200)
        _ = try fixture.put(.lastValidatorEra, json: "\"72\"", account: account)
        _ = try fixture.put(.areNominatorsSlashable, json: "true")
        let slashable = try await run(factory.create(accountId: account, runtime: fixture.runtime, connection: fixture))
        XCTAssertEqual(slashable.unlocking, 2_419_200)
    }

    func testBondedEraSessionLookupUsesActiveEraAndRejectsMissingOrAmbiguousEntries() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let storage = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let factory = EraCountdownOperationFactory(storageRequestFactory: storage)
        for (json, expected) in [("[[\"99\",\"600\"],[\"100\",\"606\"]]", UInt32(606)),
                                 ("[[\"99\",\"600\"]]", nil),
                                 ("[[\"100\",\"606\"],[\"100\",\"607\"]]", nil)] {
            _ = try fixture.put(.bondedEras, json: json)
            let coder = fixture.runtime.fetchCoderFactoryOperation()
            let active = ClosureOperation<[StorageResponse<ActiveEraInfo>]> {
                let value = try JSONDecoder().decode(ActiveEraInfo.self, from: Data("{\"index\":\"100\",\"start\":null}".utf8))
                return [StorageResponse(key: Data(), data: nil, value: value)]
            }
            let wrapper = factory.createBondedEraStartSessionIndex(dependingOn: active, codingFactoryOperation: coder, engine: fixture)
            wrapper.allOperations.forEach { $0.addDependency(coder) }
            let combined = CompoundOperationWrapper(targetOperation: wrapper.targetOperation, dependencies: wrapper.dependencies + [active, coder])
            do {
                let result = try await run(combined)
                XCTAssertEqual(result.first?.value?.value, expected)
                XCTAssertNotNil(expected, "Ambiguous or absent active-era mapping must fail")
            } catch { XCTAssertNil(expected, "Valid active-era mapping must succeed: \(error)") }
        }
    }

    private func baseEra(_ fixture: AssetHubStorageFixture, validator: Data) throws {
        _ = try fixture.put(.activeEra, json: "{\"index\":\"12\",\"start\":null}")
        _ = try fixture.put(.currentEra, json: "\"12\"")
        _ = try fixture.put(.erasStakersOverview, json: "{\"total\":\"300\",\"own\":\"100\",\"nominator_count\":\"1\",\"page_count\":\"1\"}", era: 11, account: validator)
        _ = try fixture.put(.erasPrefs, json: "{\"commission\":\"200000000\",\"blocked\":false}", era: 11, account: validator)
        _ = try fixture.put(.totalValidatorReward, json: "\"3000\"", era: 11)
        _ = try fixture.put(.rewardPointsPerValidator, json: "{\"total\":\"3\",\"individual\":[[\"\(validator.toHex(includePrefix: true))\",\"3\"]]}", era: 11)
    }

    private func chain(_ fixture: AssetHubStorageFixture) throws -> ChainModel {
        let route = try XCTUnwrap(AssetHubStakingRoute.staking(on: fixture.runtime.chainId))
        let asset = AssetModel(
            id: route.nativeAssetId, name: "DOT", symbol: "DOT", precision: 10,
            isUtility: true, isNative: false, staking: .assetHub, type: .normal
        )
        let listed = ChainModel(
            rank: nil, disabled: false, chainId: route.stakingChainId, parentId: route.relayChainId, paraId: "1000",
            name: "Asset Hub", assets: [asset], xcm: nil,
            nodes: [ChainNodeModel(url: URL(string: "wss://example.com")!, name: "test", apikey: nil)],
            addressPrefix: 0, icon: nil, iosMinAppVersion: nil, identityChain: nil
        )
        return try XCTUnwrap(NetworkRetirement.offered(listed))
    }

    private func run<Value>(_ wrapper: CompoundOperationWrapper<Value>) async throws -> Value {
        let manager = OperationManager()
        let completed = expectation(description: "Asset Hub operation completes")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        manager.enqueue(operations: wrapper.allOperations, in: .transient)
        await fulfillment(of: [completed], timeout: 30)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }

    private struct FixedDuration: StakingDurationOperationFactoryProtocol {
        func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
            CompoundOperationWrapper(targetOperation: ClosureOperation { StakingDuration(session: 14400, era: 86400, unlocking: 2_419_200) })
        }
    }
}
