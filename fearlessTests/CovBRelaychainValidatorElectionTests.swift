import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovBRvElectedValidatorsTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testAllElectedMapsSlashesIdentitiesReturnsAndElectionState() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)]),
            try Fx.validator(Fx.validatorB, total: 100, own: 100, blocked: true)
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]
        fx.storage.put(.unappliedSlashes, param: "8", json: [["validator": Fx.validatorB.base64EncodedString()]])
        fx.identity.identities = [try fx.address(Fx.validatorA): AccountIdentity(name: "Ay")]

        let result = try Fx.execute(fx.factory().allElectedOperation())

        XCTAssertEqual(result.map(\.address), try [Fx.validatorA, Fx.validatorB].map(fx.address))
        XCTAssertTrue(result[0].elected)
        XCTAssertFalse(result[0].hasSlashes)
        XCTAssertEqual(result[0].stakeReturn, 0.1)
        XCTAssertEqual(result[0].identity?.name, "Ay")
        XCTAssertEqual(result[0].comission, 0.2)
        XCTAssertEqual(result[0].maxNominatorsRewarded, 2)
        XCTAssertEqual(result[0].nominators, [NominatorInfo(address: try fx.address(Fx.nominator), stake: 2)])
        XCTAssertEqual(result[0].totalStake, 3)
        XCTAssertEqual(result[0].ownStake, 1)
        XCTAssertFalse(result[1].elected, "A validator without nominators is not counted as elected")
        XCTAssertTrue(result[1].hasSlashes)
        XCTAssertTrue(result[1].blocked)
        XCTAssertEqual(result[1].stakeReturn, 0, "A validator unknown to the reward engine earns nothing")
        XCTAssertEqual(fx.storage.requests(.unappliedSlashes), [["7", "8", "9", "10"]])
        XCTAssertEqual(fx.identity.requestedIds, [[Fx.validatorA, Fx.validatorB]])
    }

    func testAllElectedSkipsSlashErasWhileTheActiveEraIsWithinTheDeferDuration() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 3, validators: [try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 1)])])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]

        let result = try Fx.execute(fx.factory().allElectedOperation())

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(fx.storage.requests(.unappliedSlashes), [[]])
    }

    func testAllElectedFailsWithoutTheSlashDeferConstant() throws {
        let fx = try CovBRvFixture(constants: [.maxNominatorRewardedPerValidator: 2])
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        XCTAssertThrowsError(try Fx.execute(fx.factory().allElectedOperation()))
        XCTAssertTrue(fx.storage.requests(.unappliedSlashes).isEmpty)
    }

    func testAllElectedFailsWhenTheRuntimeCannotBeFetched() throws {
        let fx = try CovBRvFixture()
        fx.constants.failure = CovBSkError(code: 11)
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        covBRvAssertError(fx.factory().allElectedOperation()) { ($0 as? CovBSkError)?.code == 11 }
    }

    func testAllElectedPropagatesEraAndRewardFailures() throws {
        let fx = try CovBRvFixture()
        fx.era.failure = CovBSkError(code: 12)
        covBRvAssertError(fx.factory().allElectedOperation()) { ($0 as? CovBSkError)?.code == 12 }
        fx.era.failure = nil
        fx.reward.failure = CovBSkError(code: 13)
        covBRvAssertError(fx.factory().allElectedOperation()) { ($0 as? CovBSkError)?.code == 13 }
    }

    func testAllElectedReportsMissingRuntimeAndConnection() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        fx.removeConnection()
        covBRvAssertError(fx.factory().allElectedOperation(), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().allElectedOperation(), covBRvIsRuntimeError)
    }

    func testWannabeValidatorsKeepOnlyValidatorsWithPrefs() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)])])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]
        fx.storage.put(.validatorPrefs, account: Fx.validatorA, json: ["commission": "100000000", "blocked": false])
        fx.storage.put(.validatorPrefs, account: Fx.validatorD, json: ["commission": "5", "blocked": true])
        fx.storage.put(.unappliedSlashes, param: "9", json: [["validator": Fx.validatorD.base64EncodedString()]])
        fx.identity.identities = [try fx.address(Fx.validatorD): AccountIdentity(name: "Dee")]

        let result = try Fx.execute(fx.factory().wannabeValidatorsOperation(for: [Fx.validatorA, Fx.validatorC, Fx.validatorD]))

        XCTAssertEqual(result.map(\.address), try [Fx.validatorA, Fx.validatorD].map(fx.address))
        guard case .elected? = result[0].myNomination else { return XCTFail("A is elected") }
        XCTAssertNotNil(result[0].stakeInfo)
        XCTAssertFalse(result[0].hasSlashes)
        XCTAssertFalse(result[0].blocked)
        // Current behaviour: the perbill commission is read as a token amount with the asset precision (reported).
        XCTAssertEqual(result[0].commission, 1_000_000)
        guard case .unelected? = result[1].myNomination else { return XCTFail("D is not elected") }
        XCTAssertNil(result[1].stakeInfo)
        XCTAssertTrue(result[1].hasSlashes)
        XCTAssertTrue(result[1].blocked)
        XCTAssertEqual(result[1].commission, 0.05)
        XCTAssertEqual(result[1].identity?.name, "Dee")
        XCTAssertEqual(fx.storage.requests(.validatorPrefs), [[Fx.validatorA, Fx.validatorC, Fx.validatorD].map { $0.toHex() }])
    }

    func testWannabeValidatorsPropagateStorageFailure() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        fx.storage.failure = CovBSkError(code: 21)
        covBRvAssertError(fx.factory().wannabeValidatorsOperation(for: [Fx.validatorA])) { ($0 as? CovBSkError)?.code == 21 }
    }

    func testWannabeValidatorsReportMissingConnectionAndRuntime() throws {
        let fx = try CovBRvFixture()
        fx.removeConnection()
        covBRvAssertError(fx.factory().wannabeValidatorsOperation(for: [Fx.validatorA]), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().wannabeValidatorsOperation(for: [Fx.validatorA]), covBRvIsRuntimeError)
    }
}

final class CovBRvAllValidatorsTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private func makeFixture() throws -> (CovBRvFixture, CovBSkEngine) {
        let source = try AssetHubStorageFixture()
        _ = try source.put(.validatorPrefs, json: "{\"commission\":\"200000000\",\"blocked\":false}", account: Fx.validatorA)
        _ = try source.put(.validatorPrefs, json: "{\"commission\":\"300000000\",\"blocked\":true}", account: Fx.validatorB)
        let engine = CovBSkEngine(source: source)
        let fx = try CovBRvFixture()
        fx.registry.register(fx.chain.chainId, connection: engine, runtime: source.runtime)
        return (fx, engine)
    }

    func testFetchAllValidatorsListsElectedValidatorsBeforeWaitingOnes() throws {
        let (fx, engine) = try makeFixture()
        fx.era.info = EraStakersInfo(activeEra: 100, validators: [try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)])])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1, Fx.validatorB: 0.2]
        fx.storage.put(.unappliedSlashes, param: "100", json: [["validator": Fx.validatorB.base64EncodedString()]])
        fx.identity.identities = [try fx.address(Fx.validatorB): AccountIdentity(name: "Bee")]

        let result = try Fx.execute(fx.factory().fetchAllValidators())

        XCTAssertEqual(result.map(\.address), try [Fx.validatorA, Fx.validatorB].map(fx.address))
        XCTAssertTrue(result[0].elected)
        XCTAssertEqual(result[0].nominators.count, 1)
        XCTAssertEqual(result[0].comission, 0.2)
        XCTAssertFalse(result[0].hasSlashes)
        XCTAssertNil(result[0].maxNominatorsRewarded, "Asset Hub staking has no rewarded nominator limit")
        XCTAssertFalse(result[1].elected)
        XCTAssertTrue(result[1].blocked)
        XCTAssertTrue(result[1].hasSlashes)
        XCTAssertEqual(result[1].comission, 0.3)
        XCTAssertEqual(result[1].stakeReturn, 0.2)
        XCTAssertEqual(result[1].totalStake, 0)
        XCTAssertEqual(result[1].identity?.name, "Bee")
        XCTAssertEqual(Set(fx.identity.requestedIds.first ?? []), [Fx.validatorA, Fx.validatorB])
        XCTAssertEqual(fx.storage.requests(.unappliedSlashes).first?.last, "100")
        XCTAssertTrue(engine.methods.contains("state_getKeysPaged"))
        XCTAssertTrue(engine.methods.contains("state_queryStorageAt"))
    }

    func testFetchAllValidatorsReadAListedKeyWithoutAValueAsTheDefaultPrefs() throws {
        let (fx, engine) = try makeFixture()
        let prefix = try StorageKeyFactory().key(from: .validatorPrefs).toHex(includePrefix: true)
        engine.emptyKeys = [prefix + String(repeating: "ff", count: 48)]
        fx.era.info = EraStakersInfo(activeEra: 100, validators: [])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1, Fx.validatorB: 0.2]

        let result = try Fx.execute(fx.factory().fetchAllValidators())

        // Staking.Validators is a value query: an empty read decodes to its default (no commission, not blocked).
        let listed = try fx.address(Data(repeating: 0xFF, count: 32))
        XCTAssertEqual(Set(result.map(\.address)), Set(try [Fx.validatorA, Fx.validatorB].map(fx.address) + [listed]))
        XCTAssertTrue(result.allSatisfy { !$0.elected })
        let defaulted = try XCTUnwrap(result.first { $0.address == listed })
        XCTAssertEqual(defaulted.comission, 0)
        XCTAssertFalse(defaulted.blocked)
        XCTAssertEqual(defaulted.stakeReturn, 0, "The reward engine does not know this validator")
    }

    func testFetchAllValidatorsPropagatesNodeFailure() throws {
        let (fx, engine) = try makeFixture()
        engine.failure = CovBSkError(code: 31)
        fx.era.info = EraStakersInfo(activeEra: 100, validators: [])
        XCTAssertThrowsError(try Fx.execute(fx.factory().fetchAllValidators()))
    }

    func testFetchAllValidatorsReportsMissingConnectionAndRuntime() throws {
        let fx = try CovBRvFixture()
        fx.removeConnection()
        covBRvAssertError(fx.factory().fetchAllValidators(), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().fetchAllValidators(), covBRvIsRuntimeError)
    }

    func testAssetHubSlashesAreReadFromTheHubStorage() throws {
        let source = try AssetHubStorageFixture()
        _ = try source.put(.validatorSlashInEra, json: "[\"1\",\"10\"]", era: 9, account: Fx.validatorA)
        let hub = AssetHubStakingRoute.routes[0].stakingChainId
        let fx = try CovBRvFixture(chain: Fx.chain(id: hub))
        fx.registry.register(hub, connection: source, runtime: source.runtime)
        fx.era.info = EraStakersInfo(activeEra: 12, validators: [try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)])])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]
        let nomination = try Fx.nomination(targets: [Fx.validatorA, Fx.validatorB], submittedIn: 5)

        let result = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        XCTAssertEqual(result.map(\.hasSlashes), [true, false])
        XCTAssertTrue(fx.storage.requests(.slashingSpans).isEmpty, "Hub slashes never use the relay slashing spans")
    }

    func testAssetHubUnappliedSlashesMarkWannabeValidators() throws {
        let source = try AssetHubStorageFixture()
        let slash = "{\"validator\":\"\(Fx.validatorD.toHex(includePrefix: true))\",\"own\":\"100\",\"others\":[],\"reporter\":null,\"payout\":\"0\"}"
        _ = try source.put(.unappliedSlashes, json: slash, era: 11, account: Fx.validatorD, page: 0)
        let hub = AssetHubStakingRoute.routes[0].stakingChainId
        let fx = try CovBRvFixture(chain: Fx.chain(id: hub))
        fx.registry.register(hub, connection: source, runtime: source.runtime)
        fx.era.info = EraStakersInfo(activeEra: 12, validators: [])
        fx.storage.put(.validatorPrefs, account: Fx.validatorD, json: ["commission": "0", "blocked": false])

        let result = try Fx.execute(fx.factory().wannabeValidatorsOperation(for: [Fx.validatorD]))

        XCTAssertEqual(result.map(\.hasSlashes), [true])
        XCTAssertTrue(fx.storage.requests(.unappliedSlashes).isEmpty, "Hub unapplied slashes are paged from the hub")
    }

    func testAssetHubSlashesWithoutRuntimeReportTheMissingRuntime() throws {
        let hub = AssetHubStakingRoute.routes[0].stakingChainId
        let fx = try CovBRvFixture(chain: Fx.chain(id: hub))
        fx.removeRuntime()
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)
        let slashes = fx.factory().createSlashesOperation(for: nomination.targets, nomination: nomination)
        covBRvAssertError(slashes, covBRvIsRuntimeError)
        let unapplied = fx.factory().createUnappliedSlashesWrapper(
            dependingOn: { 10 },
            runtime: fx.constants.fetchCoderFactoryOperation(),
            slashDefer: ClosureOperation { 3 }
        )
        covBRvAssertError(unapplied, covBRvIsRuntimeError)
    }

    func testAllValidatorsOperationQueriesPrefsByPrefix() throws {
        let fx = try CovBRvFixture()
        fx.storage.putPrefixed(.validatorPrefs, key: Fx.validatorA, json: ["commission": "7", "blocked": false])
        let runtime = fx.constants.fetchCoderFactoryOperation()
        let wrapper = fx.factory().createAllValidatorsOperation(dependingOn: runtime)
        var operations: [Operation] = [runtime]
        operations += wrapper.allOperations
        OperationQueue().addOperations(operations, waitUntilFinished: true)
        let responses = try XCTUnwrap(wrapper.targetOperation.result).get()
        XCTAssertEqual(responses.map(\.key), [Fx.validatorA])
        XCTAssertEqual(responses.first?.value?.commission, 7)
        XCTAssertEqual(fx.storage.requests(.validatorPrefs), [[try StorageKeyFactory().key(from: .validatorPrefs).toHex()]])
        fx.removeConnection()
        covBRvAssertError(fx.factory().createAllValidatorsOperation(dependingOn: runtime), covBRvIsConnectionError)
    }
}
