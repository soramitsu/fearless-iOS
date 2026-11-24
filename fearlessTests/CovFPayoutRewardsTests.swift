import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFPayoutRewardsTests: XCTestCase {
    func testFullPayoutGraphCalculatesValidatorRewardsAndHistory() throws {
        let fixture = try CovFPayoutFixture()
        let info = try CovFFixtures.execute(fixture.service.fetchPayoutsOperationWrapper())
        XCTAssertEqual(info.activeEra, 10)
        XCTAssertEqual(info.historyDepth, 3)
        XCTAssertEqual(info.payouts.map(\.era), [7, 9])
        XCTAssertEqual(info.payouts.map(\.validator), [CovFFixtures.account, CovFFixtures.account])
        XCTAssertEqual(info.payouts.map(\.reward), [Decimal(30), Decimal(30)])
        XCTAssertEqual(fixture.identity.accounts, [CovFFixtures.account])
        XCTAssertEqual(Set(fixture.storage.stringParameters["ErasValidatorReward"] ?? []), ["7", "9"])
    }

    func testFullPayoutGraphRejectsMissingEraAndMissingResolutionFactory() throws {
        let fixture = try CovFPayoutFixture()
        fixture.storage.entries["ActiveEra"] = []
        XCTAssertThrowsError(try CovFFixtures.execute(fixture.service.fetchPayoutsOperationWrapper()))
        let unavailable = fixture.makeService(validators: nil)
        XCTAssertThrowsError(try CovFFixtures.execute(unavailable.fetchPayoutsOperationWrapper()))
    }

    func testUnclaimedErasSubtractsClaimedRewardsAndKeepsIndependentStashes() throws {
        let fixture = try CovFPayoutFixture()
        let first = try fixture.ledger(stash: CovFFixtures.account, claimed: [7, 9, 100])
        let other = Data(repeating: 2, count: 32)
        let second = try fixture.ledger(stash: other, claimed: [])
        let operation = try fixture.service.createUnclaimedEraByStashOperation(
            ledgerInfoOperation: CovFFixtures.result([first, second]),
            historyRangeOperation: CovFFixtures.result(ChainHistoryRange(currentEra: 10, activeEra: 10, historyDepth: 3))
        )
        operation.start()
        let result = try XCTUnwrap(operation.result).get()
        XCTAssertEqual(Set(result[CovFFixtures.account] ?? []), [8])
        XCTAssertEqual(Set(result[other] ?? []), [7, 8, 9])
    }

    func testHistoryMappingDropsMissingStorageValuesWithoutShiftingEra() throws {
        let fixture = try CovFPayoutFixture()
        fixture.storage.entries["ErasValidatorReward"] = []
        try fixture.storage.put(.totalValidatorReward, value: nil)
        try fixture.storage.put(.totalValidatorReward, value: "123")
        let wrapper: CompoundOperationWrapper<[EraIndex: fearless.StringScaleMapper<BigUInt>]> =
            try fixture.service.createFetchHistoryByEraOperation(
                dependingOn: CovFFixtures.result([UInt32(7), 9]), engine: MockConnection(),
                codingFactoryOperation: CovFFixtures.result(fixture.runtime.factory), path: .totalValidatorReward
            )
        let result = try CovFFixtures.execute(wrapper)
        XCTAssertEqual(Set(result.keys), [9])
        XCTAssertEqual(result[9]?.value, 123)
    }

    func testFetchAndMapOmitsNullControllers() throws {
        let fixture = try CovFPayoutFixture()
        fixture.storage.entries["Bonded"] = []
        try fixture.storage.put(.controller, value: nil)
        try fixture.storage.put(.controller, value: CovFFixtures.account.base64EncodedString())
        let wrapper: CompoundOperationWrapper<[Data]> = try fixture.service.createFetchAndMapOperation(
            dependingOn: CovFFixtures.result([CovFFixtures.account]),
            codingFactoryOperation: CovFFixtures.result(fixture.runtime.factory), path: .controller
        )
        XCTAssertEqual(try CovFFixtures.execute(wrapper), [CovFFixtures.account])
    }

    func testEraAccountHistoryDropsNullValuesAndMapsBothKeys() throws {
        let fixture = try CovFPayoutFixture()
        fixture.storage.entries["ErasValidatorPrefs"] = []
        try fixture.storage.put(.erasPrefs, value: nil)
        try fixture.storage.put(.erasPrefs, value: ["commission": "200000000", "blocked": false])
        let wrapper: CompoundOperationWrapper<[EraIndex: [Data: ValidatorPrefs]]> =
            try fixture.service.createCreateHistoryByEraAccountIdOperation(
                dependingOn: CovFFixtures.result([CovFFixtures.account: [UInt32(7), 9]]),
                codingFactoryOperation: CovFFixtures.result(fixture.runtime.factory), path: .erasPrefs
            )
        let result = try CovFFixtures.execute(wrapper)
        XCTAssertEqual(Set(result.keys), [9])
        XCTAssertEqual(result[9]?[CovFFixtures.account]?.commission, 200_000_000)
    }

    func testValidatorJoinSkipsAccountsAndErasWithoutPreferences() throws {
        let fixture = try CovFPayoutFixture()
        let exposure = ValidatorExposure(total: 200, own: 100, others: [])
        let unknown = Data(repeating: 9, count: 32)
        let operation = fixture.service.createEraValidatorsInfoOperation(
            dependingOn: CovFFixtures.result([7: [CovFFixtures.account: exposure, unknown: exposure], 8: [unknown: exposure]]),
            dependingOn: CovFFixtures.result([7: [CovFFixtures.account: ValidatorPrefs(commission: 0, blocked: false)]])
        )
        operation.start()
        let result = try XCTUnwrap(operation.result).get()
        XCTAssertEqual(result[7]?.map(\.accountId), [CovFFixtures.account])
        XCTAssertEqual(result[8]?.count, 0)
    }

    func testPayoutCalculationSortsErasAndDropsUnrewardedValidators() throws {
        let fixture = try CovFPayoutFixture()
        let validator = try AssetHubTestSupport.validator(CovFFixtures.account)
        let operation = try fixture.service.calculatePayouts(
            for: ValidatorPayoutInfoFactory(chainAsset: fixture.asset),
            dependingOn: CovFFixtures.result([UInt32(9): [validator], 7: [validator], 8: [validator]]),
            erasRewardOperation: CovFFixtures.result(try fixture.distribution()),
            historyRangeOperation: CovFFixtures.result(ChainHistoryRange(currentEra: 10, activeEra: 10, historyDepth: 3)),
            identityOperation: CovFFixtures.result([:])
        )
        operation.start()
        let result = try XCTUnwrap(operation.result).get()
        XCTAssertEqual(result.payouts.map(\.era), [7, 9])
        XCTAssertEqual(result.activeEra, 10)
        XCTAssertEqual(result.historyDepth, 3)
    }

    func testRuntimeConstantFailureIsPreserved() throws {
        let fixture = try CovFPayoutFixture()
        let failure = NSError(domain: "runtime", code: 99)
        let dependency = BaseOperation<RuntimeCoderFactoryProtocol>()
        dependency.result = .failure(failure)
        let operation: PrimitiveConstantOperation<UInt32> = fixture.service.createConstOperation(dependingOn: dependency, path: .historyDepth)
        operation.start()
        XCTAssertThrowsError(try XCTUnwrap(operation.result).get()) { XCTAssertEqual($0 as NSError, failure) }
    }

    func testNominatorAndValidatorRewardsIncludeCommissionAndIdentity() throws {
        let fixture = try CovFPayoutFixture()
        let validator = try AssetHubTestSupport.validator(CovFFixtures.account, stake: 400, own: 200)
        let identity = AccountIdentity(name: "Validator", parentName: nil)
        let identities = [try AddressFactory.address(for: CovFFixtures.account, chain: fixture.asset.chain): identity]
        let distribution = try fixture.distribution()
        let nominator = NominatorPayoutInfoFactory(addressPrefix: 42, precision: 2, chainAsset: fixture.asset)
        let validatorFactory = ValidatorPayoutInfoFactory(chainAsset: fixture.asset)
        let own = try validatorFactory.calculate(
            for: CovFFixtures.account, era: 7, validatorInfo: validator, erasRewardDistribution: distribution, identities: identities
        )
        let other = try nominator.calculate(
            for: AssetHubTestSupport.nominator, era: 7, validatorInfo: validator, erasRewardDistribution: distribution, identities: identities
        )
        XCTAssertEqual(own?.reward, 30)
        XCTAssertEqual(other?.reward, 20)
        XCTAssertEqual(own?.identity, identity)
        XCTAssertEqual(other?.identity, identity)
        XCTAssertEqual(own?.era, 7)
        XCTAssertEqual(other?.validator, CovFFixtures.account)
        XCTAssertNil(try nominator.calculate(
            for: Data(), era: 7, validatorInfo: validator, erasRewardDistribution: distribution, identities: [:]
        ))
        for factory: PayoutInfoFactoryProtocol in [nominator, validatorFactory] {
            XCTAssertNil(try factory.calculate(
                for: CovFFixtures.account, era: 8, validatorInfo: validator, erasRewardDistribution: distribution, identities: [:]
            ))
        }
    }

    func testValidatorResolutionValidatesAddressAndHandlesReleasedFactory() throws {
        let asset = CovFFixtures.asset()
        var factory: PayoutValidatorsForValidatorFactory? = PayoutValidatorsForValidatorFactory(chainAsset: asset)
        let address = try AddressFactory.address(for: CovFFixtures.account, chain: asset.chain)
        let active = try XCTUnwrap(factory).createResolutionOperation(for: address, eraRangeClosure: { nil })
        XCTAssertEqual(try CovFFixtures.execute(active), [CovFFixtures.account])
        let invalid = try XCTUnwrap(factory).createResolutionOperation(for: "invalid", eraRangeClosure: { nil })
        XCTAssertThrowsError(try CovFFixtures.execute(invalid))
        let released = try XCTUnwrap(factory).createResolutionOperation(for: address, eraRangeClosure: { nil })
        factory = nil
        XCTAssertEqual(try CovFFixtures.execute(released), [])
    }
}

private final class CovFPayoutFixture {
    let asset = CovFFixtures.asset()
    let storage = CovFStorageRequests()
    let identity = CovFPayoutIdentity()
    let runtime: StakingConstantRuntime
    lazy var service = makeService(validators: PayoutValidatorsForValidatorFactory(chainAsset: asset))

    init() throws {
        runtime = try StakingConstantRuntime(values: [.historyDepth: 3])
        try storage.put(.currentEra, value: "10")
        try storage.put(.activeEra, value: ["index": "10", "start": NSNull()])
        try storage.put(.controller, value: CovFFixtures.account.base64EncodedString())
        try storage.put(.stakingLedger, value: ledgerJSON(stash: CovFFixtures.account, claimed: [8]))
        for reward in ["10000", "10000"] { try storage.put(.totalValidatorReward, value: reward) }
        for _ in 0 ..< 2 {
            try storage.put(.rewardPointsPerValidator, value: pointsJSON())
            try storage.put(.validatorExposureClipped, value: ["total": "400", "own": "200", "others": []])
            try storage.put(.erasPrefs, value: ["commission": "200000000", "blocked": false])
        }
    }

    func makeService(validators: PayoutValidatorsFactoryProtocol?) -> PayoutRewardsService {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return PayoutRewardsService(
            chain: asset.chain, selectedAccountAddress: (try? AddressFactory.address(for: CovFFixtures.account, chain: asset.chain)) ?? "",
            validatorsResolutionFactory: validators, runtimeCodingService: runtime, storageRequestFactory: storage,
            engine: MockConnection(), operationManager: OperationManager(operationQueue: queue), identityOperationFactory: identity,
            payoutInfoFactory: ValidatorPayoutInfoFactory(chainAsset: asset)
        )
    }

    func ledgerJSON(stash: Data, claimed: [UInt32]) -> [String: Any] {
        ["stash": stash.base64EncodedString(), "total": "400", "active": "400", "unlocking": [], "claimedRewards": claimed.map(String.init)]
    }

    func ledger(stash: Data, claimed: [UInt32]) throws -> StakingLedger {
        try JSONDecoder().decode(StakingLedger.self, from: JSONSerialization.data(withJSONObject: ledgerJSON(stash: stash, claimed: claimed)))
    }

    func pointsJSON() -> [String: Any] {
        ["total": "10", "individual": [[CovFFixtures.account.base64EncodedString(), "5"]]]
    }

    func distribution() throws -> ErasRewardDistribution {
        let points = try JSONDecoder().decode(EraRewardPoints.self, from: JSONSerialization.data(withJSONObject: pointsJSON()))
        return ErasRewardDistribution(totalValidatorRewardByEra: [7: 10000, 9: 20000], validatorPointsDistributionByEra: [7: points, 9: points])
    }
}

private final class CovFPayoutIdentity: IdentityOperationFactoryProtocol {
    var accounts: [Data] = []
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId], engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol, chain _: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            self.accounts = try accountIdClosure()
            return [:]
        })
    }
}
