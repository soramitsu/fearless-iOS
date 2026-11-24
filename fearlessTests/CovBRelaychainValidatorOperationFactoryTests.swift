import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovBRvFixture {
    typealias Fx = CovBSkFixtures

    let chain: ChainModel
    let token: AssetModel
    let registry = CovBSkRegistry()
    let storage = CovBSkStorage()
    let identity = CovBSkIdentityFactory()
    let era = CovBSkEraService()
    let rewardEngine = CovBSkRewardEngine()
    let reward: CovBSkRewardService
    let constants: StakingConstantRuntime
    let connection = MockConnection()

    static let defaultConstants: [fearless.ConstantCodingPath: UInt32] = [
        .maxNominatorRewardedPerValidator: 2, .slashDeferDuration: 3
    ]

    init(chain: ChainModel = Fx.chain(), constants: [fearless.ConstantCodingPath: UInt32] = CovBRvFixture.defaultConstants) throws {
        self.chain = chain
        token = try XCTUnwrap(chain.assets.first)
        self.constants = try StakingConstantRuntime(values: constants)
        reward = CovBSkRewardService(engine: rewardEngine)
        registry.register(chain.chainId, connection: connection, runtime: CovBSkRuntimeProvider(self.constants))
    }

    func factory() -> RelaychainValidatorOperationFactory {
        RelaychainValidatorOperationFactory(
            asset: token,
            chain: chain,
            eraValidatorService: era,
            rewardService: reward,
            storageRequestFactory: storage,
            identityOperationFactory: identity,
            chainRegistry: registry
        )
    }

    func address(_ id: Data) throws -> AccountAddress {
        try Fx.address(id, chain: chain)
    }

    func removeConnection() {
        registry.register(chain.chainId, connection: nil, runtime: CovBSkRuntimeProvider(constants))
    }

    func removeRuntime() {
        registry.register(chain.chainId, connection: connection, runtime: nil)
    }
}

func covBRvAssertError<T>(
    _ wrapper: CompoundOperationWrapper<T>,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ check: (Error) -> Bool
) {
    XCTAssertThrowsError(try CovBSkFixtures.execute(wrapper), file: file, line: line) { error in
        XCTAssertTrue(check(error), "unexpected \(error)", file: file, line: line)
    }
}

func covBRvIsConnectionError(_ error: Error) -> Bool {
    if case ChainRegistryError.connectionUnavailable = error { return true }
    return false
}

func covBRvIsRuntimeError(_ error: Error) -> Bool {
    if case ChainRegistryError.runtimeMetadaUnavailable = error { return true }
    return false
}

final class CovBRvSelectedValidatorsTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testAllSelectedMergesStatusesSlashesStakeAndIdentities() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)]),
            try Fx.validator(Fx.validatorB, others: [(Fx.other, 50)], commission: 50_000_000)
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1, Fx.validatorB: 0.05]
        fx.storage.put(.slashingSpans, account: Fx.validatorA, json: ["lastNonzeroSlash": "9", "prior": []])
        fx.storage.put(.slashingSpans, account: Fx.validatorB, json: ["lastNonzeroSlash": "4", "prior": []])
        fx.identity.identities = [try fx.address(Fx.validatorB): AccountIdentity(name: "Bee")]
        let nomination = try Fx.nomination(targets: [Fx.validatorA, Fx.validatorB, Fx.validatorC], submittedIn: 5)

        let result = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        XCTAssertEqual(result.map(\.address), try [Fx.validatorA, Fx.validatorB, Fx.validatorC].map(fx.address))
        guard case let .active(allocation)? = result[0].myNomination else { return XCTFail("A is active") }
        XCTAssertEqual(allocation.amount, 2)
        XCTAssertTrue(allocation.isRewarded)
        XCTAssertTrue(result[0].hasSlashes)
        XCTAssertEqual(result[0].commission, 0.2)
        XCTAssertEqual(result[0].stakeInfo?.totalStake, 3)
        XCTAssertEqual(result[0].stakeInfo?.stakeReturn, 0.1)
        XCTAssertEqual(result[0].stakeInfo?.maxNominatorsRewarded, 2)
        XCTAssertEqual(result[0].stakeInfo?.nominators, [NominatorInfo(address: try fx.address(Fx.nominator), stake: 2)])
        XCTAssertNil(result[0].identity)

        guard case .elected? = result[1].myNomination else { return XCTFail("B is elected") }
        XCTAssertFalse(result[1].hasSlashes)
        XCTAssertEqual(result[1].commission, 0.05)
        XCTAssertEqual(result[1].identity?.name, "Bee")
        XCTAssertEqual(result[1].stakeInfo?.stakeReturn, 0.05)

        guard case .unelected? = result[2].myNomination else { return XCTFail("C is not elected") }
        XCTAssertNil(result[2].stakeInfo)
        XCTAssertEqual(result[2].commission, 0)
        XCTAssertFalse(result[2].hasSlashes)

        XCTAssertEqual(fx.storage.requests(.slashingSpans), [[Fx.validatorA, Fx.validatorB, Fx.validatorC].map { $0.toHex() }])
        XCTAssertEqual(fx.identity.requestedIds, [[Fx.validatorA, Fx.validatorB, Fx.validatorC]])
    }

    func testAllSelectedMarksNominationBeyondTheRewardedLimitAsNotRewarded() throws {
        let fx = try CovBRvFixture(constants: [.maxNominatorRewardedPerValidator: 1, .slashDeferDuration: 3])
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.other, 300), (Fx.nominator, 150)])
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)

        let result = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        guard case let .active(allocation)? = result.first?.myNomination else { return XCTFail("A is active") }
        XCTAssertEqual(allocation.amount, 1.5)
        XCTAssertFalse(allocation.isRewarded)
        XCTAssertEqual(result.first?.stakeInfo?.maxNominatorsRewarded, 1)
        XCTAssertEqual(result.first?.stakeInfo?.oversubscribed, true)
    }

    func testAllSelectedWithoutRewardLimitConstantRewardsEveryNomination() throws {
        let fx = try CovBRvFixture(constants: [.slashDeferDuration: 3])
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.other, 300), (Fx.other, 200), (Fx.nominator, 150)])
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1]
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)

        let result = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        guard case let .active(allocation)? = result.first?.myNomination else { return XCTFail("A is active") }
        XCTAssertTrue(allocation.isRewarded)
        XCTAssertNil(result.first?.stakeInfo?.maxNominatorsRewarded)
        XCTAssertEqual(result.first?.stakeInfo?.oversubscribed, false)
    }

    func testAllSelectedFailsWhenRewardCalculatorFails() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [try Fx.validator(Fx.validatorA)])
        fx.reward.failure = CovBSkError(code: 7)
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)
        covBRvAssertError(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator))) {
            ($0 as? CovBSkError) == CovBSkError(code: 7)
        }
    }

    func testAllSelectedFailsWhenElectedValidatorIsMissingFromTheRewardEngine() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [try Fx.validator(Fx.validatorA)])
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)
        covBRvAssertError(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator))) {
            if case let RewardCalculatorEngineError.unexpectedValidator(accountId) = $0 { return accountId == Fx.validatorA }
            return false
        }
    }

    func testAllSelectedWithoutConnectionReportsTheMissingConnection() throws {
        let fx = try CovBRvFixture()
        fx.removeConnection()
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)
        covBRvAssertError(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)), covBRvIsConnectionError)
    }

    func testAllSelectedWithoutRuntimeReportsTheMissingRuntime() throws {
        let fx = try CovBRvFixture()
        fx.removeRuntime()
        let nomination = try Fx.nomination(targets: [Fx.validatorA], submittedIn: 5)
        covBRvAssertError(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)), covBRvIsRuntimeError)
    }

    func testIdentitiesComeFromTheIdentityChainWhenItIsAvailable() throws {
        let fx = try CovBRvFixture(chain: Fx.chain(identityChain: "covb-people"))
        let peopleConnection = MockConnection()
        let peopleRuntime = CovBSkRuntimeProvider(try StakingConstantRuntime(values: [:]))
        fx.registry.register("covb-people", connection: peopleConnection, runtime: peopleRuntime)
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        let nomination = try Fx.nomination(targets: [Fx.validatorC], submittedIn: 5)

        let result = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(fx.identity.engines.first === peopleConnection)
        XCTAssertTrue((fx.identity.runtimes.first as? CovBSkRuntimeProvider) === peopleRuntime)
    }

    func testIdentitiesFallBackToTheStakingChainWhenTheIdentityChainIsUnknown() throws {
        let fx = try CovBRvFixture(chain: Fx.chain(identityChain: "covb-missing"))
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [])
        let nomination = try Fx.nomination(targets: [Fx.validatorC], submittedIn: 5)

        _ = try Fx.execute(fx.factory().allSelectedOperation(by: nomination, nominatorAddress: try fx.address(Fx.nominator)))

        XCTAssertTrue(fx.identity.engines.first === fx.connection)
        let runtime = try XCTUnwrap(fx.identity.runtimes.first as? CovBSkRuntimeProvider)
        XCTAssertTrue((runtime.base as? StakingConstantRuntime) === fx.constants)
    }
}

final class CovBRvActiveAndPendingTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testActiveValidatorsKeepOnlyValidatorsRewardingTheNominator() throws {
        let fx = try CovBRvFixture(constants: [.maxNominatorRewardedPerValidator: 1])
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)]),
            try Fx.validator(Fx.validatorB, others: [(Fx.other, 100), (Fx.nominator, 50)]),
            try Fx.validator(Fx.validatorC, others: [(Fx.other, 10)])
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1, Fx.validatorB: 0.2, Fx.validatorC: 0.3]
        fx.identity.identities = [try fx.address(Fx.validatorA): AccountIdentity(name: "Ay")]

        let result = try Fx.execute(fx.factory().activeValidatorsOperation(for: try fx.address(Fx.nominator)))

        XCTAssertEqual(result.map(\.address), [try fx.address(Fx.validatorA)])
        guard case let .active(allocation)? = result.first?.myNomination else { return XCTFail("A is active") }
        XCTAssertEqual(allocation.amount, 2)
        XCTAssertTrue(allocation.isRewarded)
        XCTAssertEqual(result.first?.identity?.name, "Ay")
        XCTAssertEqual(result.first?.stakeInfo?.stakeReturn, 0.1)
        XCTAssertEqual(result.first?.stakeInfo?.totalStake, 3)
        XCTAssertEqual(fx.identity.requestedIds, [[Fx.validatorA]])
    }

    func testActiveValidatorsWithoutRewardLimitIncludeEveryExposure() throws {
        let fx = try CovBRvFixture(constants: [:])
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200)]),
            try Fx.validator(Fx.validatorB, others: [(Fx.other, 100), (Fx.nominator, 50)])
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.1, Fx.validatorB: 0.2]

        let result = try Fx.execute(fx.factory().activeValidatorsOperation(for: try fx.address(Fx.nominator)))
            .sorted { $0.address < $1.address }

        let expected = try [Fx.validatorA, Fx.validatorB].map(fx.address).sorted()
        XCTAssertEqual(result.map(\.address), expected)
        let validatorB = try XCTUnwrap(result.first { $0.address == (try? fx.address(Fx.validatorB)) })
        guard case let .active(allocation)? = validatorB.myNomination else { return XCTFail("B is active") }
        XCTAssertEqual(allocation.amount, 0.5)
        XCTAssertTrue(allocation.isRewarded)
        XCTAssertNil(validatorB.stakeInfo?.maxNominatorsRewarded)
    }

    func testActiveValidatorsFailForAnInvalidNominatorAddress() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 1)])])
        XCTAssertThrowsError(try Fx.execute(fx.factory().activeValidatorsOperation(for: "not-an-address")))
    }

    func testActiveValidatorsReportMissingConnectionAndRuntime() throws {
        let fx = try CovBRvFixture()
        fx.removeConnection()
        covBRvAssertError(fx.factory().activeValidatorsOperation(for: try fx.address(Fx.nominator)), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().activeValidatorsOperation(for: try fx.address(Fx.nominator)), covBRvIsRuntimeError)
    }

    func testPendingValidatorsMapStakeInfoAndIdentityInRequestOrder() throws {
        let fx = try CovBRvFixture()
        fx.era.info = EraStakersInfo(activeEra: 10, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200), (Fx.other, 50)], total: 500)
        ])
        fx.rewardEngine.returns = [Fx.validatorA: 0.12]
        fx.identity.identities = [try fx.address(Fx.validatorC): AccountIdentity(name: "Cee")]

        let result = try Fx.execute(fx.factory().pendingValidatorsOperation(for: [Fx.validatorC, Fx.validatorA]))

        XCTAssertEqual(result.map(\.address), try [Fx.validatorC, Fx.validatorA].map(fx.address))
        XCTAssertNil(result[0].stakeInfo)
        XCTAssertEqual(result[0].identity?.name, "Cee")
        XCTAssertNil(result[0].myNomination)
        XCTAssertEqual(result[1].stakeInfo?.totalStake, 5)
        XCTAssertEqual(result[1].stakeInfo?.ownStake, 2.5)
        XCTAssertEqual(result[1].stakeInfo?.nominators.map(\.stake), [2, 0.5])
        XCTAssertEqual(result[1].stakeInfo?.stakeReturn, 0.12)
        XCTAssertNil(result[1].myNomination)
    }

    func testPendingValidatorsPropagateIdentityFailure() throws {
        let fx = try CovBRvFixture()
        fx.identity.failure = CovBSkError(code: 3)
        covBRvAssertError(fx.factory().pendingValidatorsOperation(for: [Fx.validatorA])) { ($0 as? CovBSkError)?.code == 3 }
    }

    func testPendingValidatorsReportMissingConnectionAndRuntime() throws {
        let fx = try CovBRvFixture()
        fx.removeConnection()
        covBRvAssertError(fx.factory().pendingValidatorsOperation(for: [Fx.validatorA]), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().pendingValidatorsOperation(for: [Fx.validatorA]), covBRvIsRuntimeError)
    }

    func testNominationReturnsTheStoredNomination() throws {
        let fx = try CovBRvFixture()
        fx.storage.put(.nominators, account: Fx.nominator, json: [
            "targets": [Fx.validatorA.toHex(includePrefix: true), Fx.validatorB.toHex(includePrefix: true)],
            "submittedIn": "12"
        ])

        let nomination = try Fx.execute(fx.factory().nomination(accountId: Fx.nominator))

        XCTAssertEqual(nomination?.targets, [Fx.validatorA, Fx.validatorB])
        XCTAssertEqual(nomination?.submittedIn, 12)
        XCTAssertEqual(fx.storage.requests(.nominators), [[Fx.nominator.toHex()]])
    }

    func testNominationIsNilWhenNothingIsStored() throws {
        let fx = try CovBRvFixture()
        XCTAssertNil(try Fx.execute(fx.factory().nomination(accountId: Fx.nominator)))
    }

    func testNominationReportsMissingConnectionRuntimeAndStorageFailure() throws {
        let fx = try CovBRvFixture()
        fx.storage.failure = CovBSkError(code: 5)
        covBRvAssertError(fx.factory().nomination(accountId: Fx.nominator)) { ($0 as? CovBSkError)?.code == 5 }
        fx.removeConnection()
        covBRvAssertError(fx.factory().nomination(accountId: Fx.nominator), covBRvIsConnectionError)
        fx.removeRuntime()
        covBRvAssertError(fx.factory().nomination(accountId: Fx.nominator), covBRvIsRuntimeError)
    }
}
