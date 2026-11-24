import BigInt
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFBalanceLocksTests: XCTestCase {
    func testStakingLocksSeparateActiveUnbondingAndRedeemableBalances() async throws {
        let fixture = try CovFLocksFixture()
        let result = try await fixture.service.fetchStakingLocks(for: CovFFixtures.account)
        XCTAssertEqual(result.staked, 2)
        XCTAssertEqual(result.unstaking, 3)
        XCTAssertEqual(result.redeemable, 1)
        XCTAssertNil(result.claimable)
        XCTAssertEqual(result.total, 6)
    }

    func testPoolLocksIncludePendingRewardsAndEraBoundaries() async throws {
        let fixture = try CovFLocksFixture()
        let result = try await fixture.service.fetchNominationPoolLocks(for: CovFFixtures.account)
        XCTAssertEqual(result.staked, 5)
        XCTAssertEqual(result.unstaking, 4)
        XCTAssertEqual(result.redeemable, 2)
        XCTAssertEqual(result.claimable, Decimal(string: "0.5"))
        XCTAssertEqual(fixture.pool.account, CovFFixtures.account)
    }

    func testGovernanceCrowdloanAndBothVestingStoresUseAssetPrecision() async throws {
        let fixture = try CovFLocksFixture()
        let governance = try await fixture.service.fetchGovernanceLocks(for: CovFFixtures.account)
        let crowdloan = try await fixture.service.fetchCrowdloanLocks(for: CovFFixtures.account)
        let vesting = try await fixture.service.fetchVestingLocks(for: CovFFixtures.account, currencyId: .assets(id: "1"))
        let nativeVesting = try await fixture.service.fetchVestingLocks(for: CovFFixtures.account, currencyId: nil)
        XCTAssertEqual(governance, 6)
        XCTAssertEqual(crowdloan, 15)
        XCTAssertEqual(vesting, 19)
        XCTAssertEqual(nativeVesting, 9)
        let total = try await fixture.service.fetchTotalLocks(for: CovFFixtures.account, currencyId: .assets(id: "1"))
        XCTAssertEqual(total, Decimal(string: "57.5"))
    }

    func testAssetStatusMapsLockedFrozenAndBlockedAmounts() async throws {
        let fixture = try CovFLocksFixture()
        for status in ["Liquid", "Frozen", "Blocked"] {
            fixture.storage.items["Assets.Account"] = try CovFFixtures.json(["balance": "1234", "status": [status]]).map(to: AssetAccountInfo.self)
            let currency = CurrencyId.assets(id: "1")
            let locked = try await fixture.service.fetchAssetLocks(for: CovFFixtures.account, currencyId: currency)
            let frozen = try await fixture.service.fetchAssetFrozen(for: CovFFixtures.account, currencyId: currency)
            let blocked = try await fixture.service.fetchAssetBlocked(for: CovFFixtures.account, currencyId: currency)
            let expectedAmount = Decimal(1234) / 100
            XCTAssertEqual(locked, status == "Liquid" ? 0 : expectedAmount)
            XCTAssertEqual(frozen, status == "Frozen" ? expectedAmount : 0)
            XCTAssertEqual(blocked, status == "Blocked" ? expectedAmount : 0)
        }
        let absent = try await fixture.service.fetchAssetLocks(for: CovFFixtures.account, currencyId: nil)
        let noFrozen = try await fixture.service.fetchAssetFrozen(for: CovFFixtures.account, currencyId: nil)
        let noBlocked = try await fixture.service.fetchAssetBlocked(for: CovFFixtures.account, currencyId: nil)
        XCTAssertEqual([absent, noFrozen, noBlocked], [0, 0, 0])
    }

    func testMissingStorageValuesProduceZeroLocks() async throws {
        let fixture = try CovFLocksFixture()
        fixture.storage.items = [:]
        fixture.crowdloan.values = [:]
        fixture.pool.pending = nil
        let staking = try await fixture.service.fetchStakingLocks(for: CovFFixtures.account)
        let pool = try await fixture.service.fetchNominationPoolLocks(for: CovFFixtures.account)
        let asset = try await fixture.service.fetchAssetLocks(for: CovFFixtures.account, currencyId: .assets(id: "1"))
        let total = try await fixture.service.fetchTotalLocks(for: CovFFixtures.account, currencyId: .assets(id: "1"))
        XCTAssertEqual(staking.total, 0)
        XCTAssertEqual(pool.total, 0)
        XCTAssertEqual(asset, 0)
        XCTAssertEqual(total, 0)
    }

    func testTotalIgnoresFailedComponentsWhileIndividualQueriesReportErrors() async throws {
        let fixture = try CovFLocksFixture()
        fixture.storage.failure = NSError(domain: "storage", code: 1)
        fixture.crowdloan.failure = NSError(domain: "crowdloan", code: 2)
        fixture.pool.failure = NSError(domain: "pool", code: 3)
        let total = try await fixture.service.fetchTotalLocks(for: CovFFixtures.account, currencyId: .assets(id: "1"))
        XCTAssertEqual(total, 0)
        do { _ = try await fixture.service.fetchGovernanceLocks(for: CovFFixtures.account); XCTFail("Expected storage error") }
        catch { XCTAssertEqual((error as NSError).domain, "storage") }
        fixture.storage.failure = nil
        do { _ = try await fixture.service.fetchNominationPoolLocks(for: CovFFixtures.account); XCTFail("Expected pending reward error") }
        catch { XCTAssertEqual((error as NSError).domain, "pool") }
    }

    func testUnsupportedStakingAndNonUtilityAssetsRejectUnavailableLockKinds() async throws {
        let fixture = try CovFLocksFixture(asset: CovFFixtures.asset(utility: false))
        do { _ = try await fixture.service.fetchStakingLocks(for: CovFFixtures.account); XCTFail("Expected no staking") }
        catch { XCTAssertTrue(error is BalanceLocksFetchingError) }
        do { _ = try await fixture.service.fetchNominationPoolLocks(for: CovFFixtures.account); XCTFail("Expected no pool staking") }
        catch { XCTAssertTrue(error is BalanceLocksFetchingError) }
        do { _ = try await fixture.service.fetchGovernanceLocks(for: CovFFixtures.account); XCTFail("Expected no governance lock") }
        catch { XCTAssertTrue(error is BalanceLocksFetchingError) }
        do { _ = try await fixture.service.fetchCrowdloanLocks(for: CovFFixtures.account); XCTFail("Expected no crowdloan lock") }
        catch { XCTAssertTrue(error is BalanceLocksFetchingError) }
    }
}

private final class CovFLocksFixture {
    let storage = CovFLockStorage()
    let pool = CovFLockPoolFactory()
    let crowdloan = CovFLockCrowdloan()
    let service: BalanceLocksFetchingDefault

    init(asset: ChainAsset = AssetHubTestSupport.makeAsset(chainId: SSFModels.Chain.polkadot.genesisHash)) throws {
        service = BalanceLocksFetchingDefault(storageRequestPerformer: storage, chainAsset: asset,
                                              crowdloanService: crowdloan, stakingPoolOperationFactory: pool)
        storage.items["Staking.CurrentEra"] = fearless.StringScaleMapper(value: UInt32(10))
        storage.items["Staking.Ledger"] = try CovFFixtures.json([
            "stash": CovFFixtures.account.toHex(includePrefix: true), "total": "600", "active": "200",
            "unlocking": [["value": "100", "era": "10"], ["value": "300", "era": "11"]], "claimedRewards": []
        ]).map(to: StakingLedger.self)
        storage.items["NominationPools.PoolMembers"] = try CovFFixtures.json([
            "poolId": "1", "points": "500", "unbondingEras": [["value": "200", "era": "10"], ["value": "400", "era": "11"]]
        ]).map(to: StakingPoolMember.self)
        storage.items["Balances.Locks"] = [
            BalanceLock(identifier: Data("pyconvot".utf8), amount: 600, reasons: .all),
            BalanceLock(identifier: Data("vesting ".utf8), amount: 900, reasons: .all)
        ]
        storage.items["Tokens.Locks"] = [TokenLock(id: Data("vesting ".utf8), amount: 1000)]
        crowdloan.values = [.fundIndex(1): CrowdloanContribution(balance: 700, memo: Data()),
                            .fundIndex(2): CrowdloanContribution(balance: 800, memo: Data())]
    }
}

private final class CovFLockStorage: StorageRequestPerformer {
    var items: [String: Any] = [:]
    var failure: Error?
    func performSingle<T: Decodable>(_ request: StorageRequest) async throws -> T? {
        if let failure { throw failure }
        return items[request.storagePath.moduleName + "." + request.storagePath.itemName] as? T
    }

    func performSingle<T: Decodable>(_: StorageRequest, withCacheOptions _: CachedStorageRequestTrigger) async -> AsyncThrowingStream<T?, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performMultiple<T: Decodable>(_: MultipleRequest) async throws -> [T?] { [] }
    func performMultiple<T: Decodable>(_: MultipleRequest, withCacheOptions _: CachedStorageRequestTrigger) async -> AsyncThrowingStream<[T?], Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<T: Decodable, K: Decodable & ScaleCodable>(_: PrefixRequest) async throws -> [K: T]? { nil }
}

private final class CovFLockCrowdloan: CrowdloanService {
    var values: CrowdloanContributionDict = [:]
    var failure: Error?
    func fetchContributions(accountId _: AccountId) async throws -> CrowdloanContributionDict {
        if let failure { throw failure }
        return values
    }
}

private final class CovFLockPoolFactory: StakingPoolOperationFactoryProtocol {
    var pending: BigUInt? = 50
    var failure: Error?
    var account: Data?
    func fetchPendingRewards(accountId: AccountId) -> CompoundOperationWrapper<BigUInt?> {
        account = accountId
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.pending
        })
    }

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> { .init(targetOperation: ClosureOperation { [] }) }
    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchBondedPoolOperation(poolId _: String) -> CompoundOperationWrapper<StakingPool?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> { .init(targetOperation: ClosureOperation { nil }) }
    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> { .init(targetOperation: ClosureOperation { nil }) }
}
