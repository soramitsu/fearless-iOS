import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovBOpIdentityTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private let parent = Data(repeating: 0x50, count: 32)
    private let orphanParent = Data(repeating: 0x51, count: 32)

    private func raw(_ text: String) -> [Any] {
        ["Raw", Data(text.utf8).base64EncodedString()]
    }

    private func storage() -> CovBSkStorage {
        let storage = CovBSkStorage()
        storage.put(.superIdentity, account: Fx.validatorA, json: [parent.base64EncodedString(), raw("one")])
        storage.put(.superIdentity, account: Fx.validatorD, json: [orphanParent.base64EncodedString(), raw("dee")])
        storage.put(.identity, account: parent, json: ["info": ["display": raw("Parent"), "web": raw("parent.io")]])
        storage.put(.identity, account: Fx.validatorB, json: [["info": ["display": raw("Bee"), "email": raw("b@e.e")]], NSNull()])
        return storage
    }

    func testIdentitiesResolveSubAccountsThroughTheirParents() throws {
        let storage = storage()
        let chain = Fx.chain()
        let factory = IdentityOperationFactory(requestFactory: storage)
        let accounts = [Fx.validatorA, Fx.validatorB, Fx.validatorC, Fx.validatorD]

        let result = try Fx.execute(factory.createIdentityWrapper(
            for: { accounts },
            engine: MockConnection(),
            runtimeService: try StakingConstantRuntime(),
            chain: chain
        ))

        let address = { (id: Data) in try Fx.address(id, chain: chain) }
        XCTAssertEqual(Set(result.keys), Set(try [Fx.validatorA, Fx.validatorB, Fx.validatorD].map(address)))
        let sub = try XCTUnwrap(result[try address(Fx.validatorA)])
        XCTAssertEqual(sub.name, "one")
        XCTAssertEqual(sub.parentAddress, try address(parent))
        XCTAssertEqual(sub.parentName, "Parent")
        XCTAssertEqual(sub.web, "parent.io")
        XCTAssertEqual(sub.displayName, "Parent / one")
        let own = try XCTUnwrap(result[try address(Fx.validatorB)])
        XCTAssertEqual(own.name, "Bee")
        XCTAssertNil(own.parentAddress)
        XCTAssertEqual(own.email, "b@e.e")
        XCTAssertEqual(result[try address(Fx.validatorD)], AccountIdentity(name: "dee"))
        XCTAssertEqual(storage.requests(.superIdentity), [accounts.map { $0.toHex() }])
        XCTAssertEqual(storage.requests(.identity), [[parent, Fx.validatorB, Fx.validatorC, orphanParent].map { $0.toHex() }])
    }

    func testIdentityFailuresArePropagated() throws {
        let storage = storage()
        storage.failure = CovBSkError(code: 41)
        let factory = IdentityOperationFactory(requestFactory: storage)
        XCTAssertThrowsError(try Fx.execute(factory.createIdentityWrapper(
            for: { [Fx.validatorA] }, engine: MockConnection(), runtimeService: try StakingConstantRuntime(), chain: Fx.chain()
        ))) { XCTAssertEqual($0 as? CovBSkError, CovBSkError(code: 41)) }

        let runtime = try StakingConstantRuntime()
        runtime.failure = CovBSkError(code: 42)
        XCTAssertThrowsError(try Fx.execute(IdentityOperationFactory(requestFactory: self.storage()).createIdentityWrapper(
            for: { [Fx.validatorA] }, engine: MockConnection(), runtimeService: runtime, chain: Fx.chain()
        ))) { XCTAssertEqual($0 as? CovBSkError, CovBSkError(code: 42)) }
    }

    func testAssetHubWithoutIdentityPalletAnswersNoIdentities() throws {
        let storage = storage()
        let hub = AssetHubStakingRoute.routes[0].stakingChainId
        let result = try Fx.execute(IdentityOperationFactory(requestFactory: storage).createIdentityWrapper(
            for: { [Fx.validatorA] }, engine: MockConnection(), runtimeService: try StakingConstantRuntime(), chain: Fx.chain(id: hub)
        ))
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(storage.requests(.superIdentity).isEmpty, "The hub runtime has no identity storage to read")
    }

    func testAssetHubRuntimeFailureIsReported() throws {
        let runtime = try StakingConstantRuntime()
        runtime.failure = CovBSkError(code: 43)
        let hub = AssetHubStakingRoute.routes[0].stakingChainId
        XCTAssertThrowsError(try Fx.execute(IdentityOperationFactory(requestFactory: storage()).createIdentityWrapper(
            for: { [Fx.validatorA] }, engine: MockConnection(), runtimeService: runtime, chain: Fx.chain(id: hub)
        )))
    }
}

final class CovBOpEraCountdownTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private func storage(bondedEras: Bool = false) throws -> CovBSkStorage {
        let storage = CovBSkStorage()
        let keys = StorageKeyFactory()
        storage.put(.currentSessionIndex, param: try keys.key(from: .currentSessionIndex).toHex(), json: "100")
        storage.put(.currentSlot, param: try keys.key(from: .currentSlot).toHex(), json: "2004")
        storage.put(.genesisSlot, param: try keys.key(from: .genesisSlot).toHex(), json: "1000")
        storage.put(.activeEra, param: try keys.key(from: .activeEra).toHex(), json: ["index": "5"])
        storage.put(.currentEra, param: try keys.key(from: .currentEra).toHex(), json: "6")
        storage.put(.eraStartSessionIndex, param: "5", json: "98")
        if bondedEras {
            storage.put(.bondedEras, param: try keys.key(from: .bondedEras).toHex(), json: [["4", "90"], ["5", "97"]])
        }
        return storage
    }

    private func noClock() -> StakingRuntimeClock {
        StakingRuntimeClock(runtime: { _ in nil }, connection: { _ in nil })
    }

    func testCountdownCombinesSessionSlotAndEraStorage() throws {
        let storage = try storage()
        let factory = EraCountdownOperationFactory(storageRequestFactory: storage, clock: noClock())

        let countdown = try Fx.execute(factory.fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: try StakingConstantRuntime()))

        XCTAssertEqual(countdown.activeEra, 5)
        XCTAssertEqual(countdown.currentEra, 6)
        XCTAssertEqual(countdown.eraLength, 6)
        XCTAssertEqual(countdown.sessionLength, 10)
        XCTAssertEqual(countdown.activeEraStartSessionIndex, 98)
        XCTAssertEqual(countdown.currentSessionIndex, 100)
        XCTAssertEqual(countdown.currentSlot, 2004)
        XCTAssertEqual(countdown.genesisSlot, 1000)
        XCTAssertEqual(countdown.blockCreationTime, 6000)
        XCTAssertEqual(storage.requests(.eraStartSessionIndex), [["5"]])
        // 24 of the era's 60 slots have passed, six seconds each.
        XCTAssertEqual(countdown.blockTimeInSeconds, 6)
        XCTAssertEqual(countdown.timeIntervalTillNextActiveEraStart(), 216, accuracy: 2)
        XCTAssertEqual(countdown.timeIntervalTillStart(targetEra: 8), 936, accuracy: 2)
        XCTAssertEqual(countdown.timeIntervalTillSet(targetEra: 8), 876, accuracy: 2)
        XCTAssertEqual(countdown.timeIntervalTillNextCurrentEraSet(), 516, accuracy: 2)
        XCTAssertEqual(countdown.timeIntervalTillStart(targetEra: 5), 0)
    }

    func testMissingStorageValueFailsWithNoData() throws {
        let storage = CovBSkStorage()
        let factory = EraCountdownOperationFactory(storageRequestFactory: storage, clock: noClock())
        XCTAssertThrowsError(try Fx.execute(factory.fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: try StakingConstantRuntime()))) {
            guard case EraCountdownOperationFactoryError.noData = $0 else { return XCTFail("unexpected \($0)") }
        }
    }

    func testAssetHubReadsTheRelayClockAndBondedEras() throws {
        let storage = try storage(bondedEras: true)
        let relayRuntime = try StakingConstantRuntime(values: [.sessionLength: 20, .babeBlockTime: 3000])
        let relayConnection = MockConnection()
        var requestedRelays: [String] = []
        let clock = StakingRuntimeClock(
            runtime: { requestedRelays.append($0); return relayRuntime },
            connection: { _ in relayConnection }
        )
        let route = AssetHubStakingRoute.routes[0]
        let hubRuntime = CovBSkIdentifiedRuntime(chainId: route.stakingChainId, base: try StakingConstantRuntime())

        let countdown = try Fx.execute(EraCountdownOperationFactory(storageRequestFactory: storage, clock: clock)
            .fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: hubRuntime))

        XCTAssertEqual(countdown.activeEraStartSessionIndex, 97)
        XCTAssertEqual(countdown.sessionLength, 20, "Session length comes from the relay chain")
        XCTAssertEqual(countdown.blockCreationTime, 3000)
        XCTAssertEqual(countdown.eraLength, 6, "Sessions per era come from the hub")
        XCTAssertEqual(requestedRelays, [route.relayChainId])
        XCTAssertTrue(storage.requests(.eraStartSessionIndex).isEmpty)
    }

    func testAssetHubWithoutMatchingBondedEraHasNoData() throws {
        let storage = try storage()
        storage.put(.bondedEras, param: try StorageKeyFactory().key(from: .bondedEras).toHex(), json: [["4", "90"]])
        let relayRuntime = try StakingConstantRuntime()
        let clock = StakingRuntimeClock(runtime: { _ in relayRuntime }, connection: { _ in MockConnection() })
        let hubRuntime = CovBSkIdentifiedRuntime(chainId: AssetHubStakingRoute.routes[0].stakingChainId, base: try StakingConstantRuntime())
        XCTAssertThrowsError(try Fx.execute(EraCountdownOperationFactory(storageRequestFactory: storage, clock: clock)
            .fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: hubRuntime)))
    }

    func testAssetHubWithoutRelayRuntimeOrConnectionFails() throws {
        let hubRuntime = CovBSkIdentifiedRuntime(chainId: AssetHubStakingRoute.routes[0].stakingChainId, base: try StakingConstantRuntime())
        let noRuntime = EraCountdownOperationFactory(storageRequestFactory: CovBSkStorage(), clock: noClock())
        XCTAssertThrowsError(try Fx.execute(noRuntime.fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: hubRuntime))) {
            guard case ChainRegistryError.runtimeMetadaUnavailable = $0 else { return XCTFail("unexpected \($0)") }
        }
        let relayRuntime = try StakingConstantRuntime()
        let noConnection = EraCountdownOperationFactory(
            storageRequestFactory: CovBSkStorage(),
            clock: StakingRuntimeClock(runtime: { _ in relayRuntime }, connection: { _ in nil })
        )
        XCTAssertThrowsError(try Fx.execute(noConnection.fetchCountdownOperationWrapper(for: MockConnection(), runtimeService: hubRuntime))) {
            guard case ChainRegistryError.connectionUnavailable = $0 else { return XCTFail("unexpected \($0)") }
        }
    }

    func testCountdownCreatedLongAgoNeverGoesNegative() {
        let countdown = EraCountdown(
            activeEra: 5, currentEra: 5, eraLength: 6, sessionLength: 10, activeEraStartSessionIndex: 98,
            currentSessionIndex: 100, currentSlot: 2004, genesisSlot: 1000, blockCreationTime: 6000,
            createdAtDate: Date(timeIntervalSinceNow: -10000)
        )
        XCTAssertEqual(countdown.timeIntervalTillNextActiveEraStart(), 0)
        XCTAssertEqual(countdown.timeIntervalTillNextCurrentEraSet(), 0)
    }
}

final class CovBOpNetworkInfoTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private func era() throws -> CovBSkEraService {
        let era = CovBSkEraService()
        era.info = EraStakersInfo(activeEra: 1, validators: [
            try Fx.validator(Fx.validatorA, others: [(Fx.nominator, 200), (Fx.other, 50)], total: 500),
            try Fx.validator(Fx.validatorB, others: [(Fx.nominator, 100), (Fx.validatorD, 30)], total: 300)
        ])
        return era
    }

    func testRewardedNominatorLimitSelectsActiveNominators() throws {
        let runtime = try StakingConstantRuntime(values: [.lockUpPeriod: 28, .existentialDeposit: 5, .maxNominatorRewardedPerValidator: 1])
        let factory = RelaychainStakingInfoOperationFactory(durationFactory: CovBRsDuration())

        let info = try Fx.execute(factory.networkStakingOperation(for: try era(), runtimeService: runtime))

        XCTAssertEqual(info.baseInfo.lockUpPeriod, 28)
        XCTAssertEqual(info.baseInfo.minimalBalance, 5)
        XCTAssertEqual(info.baseInfo.minStakeAmongActiveNominators, 300, "Only the first nominator of each validator is active")
        XCTAssertEqual(info.relaychainInfo?.totalStake, 800)
        XCTAssertEqual(info.relaychainInfo?.activeNominatorsCount, 1)
        XCTAssertEqual(info.relaychainInfo?.stakingDuration.era, 21600)
    }

    func testWithoutTheLimitConstantEveryNominatorIsActive() throws {
        let runtime = try StakingConstantRuntime(values: [.lockUpPeriod: 28, .existentialDeposit: 5])
        let info = try Fx.execute(RelaychainStakingInfoOperationFactory(durationFactory: CovBRsDuration())
            .networkStakingOperation(for: try era(), runtimeService: runtime))
        XCTAssertEqual(info.baseInfo.minStakeAmongActiveNominators, 30)
        XCTAssertEqual(info.relaychainInfo?.activeNominatorsCount, 3)
    }

    func testFailuresOfEraConstantsAndRuntimeArePropagated() throws {
        let factory = RelaychainStakingInfoOperationFactory(durationFactory: CovBRsDuration())
        let era = try era()
        era.failure = CovBSkError(code: 51)
        XCTAssertThrowsError(try Fx.execute(factory.networkStakingOperation(for: era, runtimeService: try StakingConstantRuntime()))) {
            XCTAssertEqual($0 as? CovBSkError, CovBSkError(code: 51))
        }
        XCTAssertThrowsError(try Fx.execute(factory.networkStakingOperation(
            for: try self.era(), runtimeService: try StakingConstantRuntime(values: [.existentialDeposit: 5])
        )), "The lock-up period is required")
        let failing = try StakingConstantRuntime()
        failing.failure = CovBSkError(code: 52)
        XCTAssertThrowsError(try Fx.execute(factory.networkStakingOperation(for: try self.era(), runtimeService: failing))) {
            XCTAssertEqual($0 as? CovBSkError, CovBSkError(code: 52))
        }
    }

    func testDefaultFactoryUsesTheChainDurationFactory() {
        XCTAssertTrue(RelaychainStakingInfoOperationFactory().durationOperationFactory is StakingDurationOperationFactory)
    }
}

final class CovBOpDurationFetcher: StakingDurationFetching {}

final class CovBOpDurationFetchingTests: XCTestCase {
    private struct CovBOpFailingDuration: StakingDurationOperationFactoryProtocol {
        let cancel: Bool

        func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
            let operation = ClosureOperation<StakingDuration> { throw CovBSkError(code: 71) }
            if cancel { operation.cancel() }
            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    private func fetch(_ factory: StakingDurationOperationFactoryProtocol) throws -> Result<StakingDuration, Error> {
        var received: Result<StakingDuration, Error>?
        let done = expectation(description: "duration")
        CovBOpDurationFetcher().fetchStakingDuration(
            runtimeCodingService: try StakingConstantRuntime(),
            operationFactory: factory,
            operationManager: OperationManager()
        ) { result in
            XCTAssertTrue(Thread.isMainThread)
            received = result
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(received)
    }

    func testDurationIsDeliveredOnTheMainQueue() throws {
        XCTAssertEqual(try fetch(CovBRsDuration(era: 3600)).get().era, 3600)
    }

    func testFailureAndCancellationAreDelivered() throws {
        XCTAssertThrowsError(try fetch(CovBOpFailingDuration(cancel: false)).get()) {
            XCTAssertEqual($0 as? CovBSkError, CovBSkError(code: 71))
        }
        XCTAssertThrowsError(try fetch(CovBOpFailingDuration(cancel: true)).get()) {
            guard case BaseOperationError.unexpectedDependentResult = $0 else { return XCTFail("unexpected \($0)") }
        }
    }
}

final class CovBOpSlashingSpansTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testRelayStashSlashingSpansAreReadForTheStashAccount() throws {
        let storage = CovBSkStorage()
        storage.put(.slashingSpans, account: Fx.validatorA, json: ["lastNonzeroSlash": "12", "prior": ["3", "4"]])
        let chain = Fx.chain()
        let factory = SlashesOperationFactory(storageRequestFactory: storage)
        let chainAsset = try CovBRsSupport.chainAsset(chain)

        let spans = try Fx.execute(factory.createSlashingSpansOperationForStash(
            try Fx.address(Fx.validatorA, chain: chain), engine: MockConnection(),
            runtimeService: try StakingConstantRuntime(), chainAsset: chainAsset
        ))
        XCTAssertEqual(spans?.lastNonzeroSlash, 12)
        XCTAssertEqual(spans?.prior.map(\.value), [3, 4])
        XCTAssertEqual(storage.requests(.slashingSpans), [[Fx.validatorA.toHex()]])

        let none = try Fx.execute(factory.createSlashingSpansOperationForStash(
            try Fx.address(Fx.validatorB, chain: chain), engine: MockConnection(),
            runtimeService: try StakingConstantRuntime(), chainAsset: chainAsset
        ))
        XCTAssertNil(none)
        XCTAssertThrowsError(try Fx.execute(factory.createSlashingSpansOperationForStash(
            "not-an-address", engine: MockConnection(), runtimeService: try StakingConstantRuntime(), chainAsset: chainAsset
        )))
    }

    func testHubWithoutAsyncSlashStorageIsUnavailable() throws {
        let hub = Fx.chain(id: AssetHubStakingRoute.routes[0].stakingChainId)
        let factory = SlashesOperationFactory(storageRequestFactory: CovBSkStorage())
        XCTAssertThrowsError(try Fx.execute(factory.createSlashingSpansOperationForStash(
            try Fx.address(Fx.validatorA, chain: hub), engine: MockConnection(),
            runtimeService: try StakingConstantRuntime(), chainAsset: try CovBRsSupport.chainAsset(hub)
        ))) {
            guard case StakingServiceFactoryError.stakingUnavailable = $0 else { return XCTFail("unexpected \($0)") }
        }
    }
}

final class CovBOpRewardEnumsTests: XCTestCase {
    func testPeriodsAndResultRates() {
        XCTAssertEqual(CalculationPeriod.day.inDays, 1)
        XCTAssertEqual(CalculationPeriod.month.inDays, 30)
        XCTAssertEqual(CalculationPeriod.year.inDays, 365)
        XCTAssertEqual(CalculationPeriod.custom(days: 12).inDays, 12)
        XCTAssertEqual(RewardCalculationResultType.percent.calculateRate(givenRate: 4), 1)
        XCTAssertEqual(RewardCalculationResultType.value.calculateRate(givenRate: 4), 4)
        XCTAssertEqual(RewardCalculatorConstants.percentCalculationAmount, 1)
        XCTAssertEqual(RewardCalculatorConstants.defaultRewardAssetRate, 1)
    }
}
