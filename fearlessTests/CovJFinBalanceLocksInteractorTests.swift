import XCTest
import SSFModels
@testable import fearless

/// Balance locks fetcher answering each category from a prepared result and recording the arguments.
final class CovJFinLocksFetcher: BalanceLocksFetching {
    var staking: Result<StakingLocks, Error> = .success(StakingLocks(staked: 10, unstaking: 3, redeemable: 2, claimable: 1))
    var pools: Result<StakingLocks, Error> = .success(StakingLocks(staked: 20, unstaking: 0, redeemable: 0, claimable: nil))
    var governance: Result<Decimal, Error> = .success(4)
    var crowdloan: Result<Decimal, Error> = .success(5)
    var vesting: Result<Decimal, Error> = .success(6)
    var frozen: Result<Decimal, Error> = .success(7)
    var blocked: Result<Decimal, Error> = .success(8)

    private let lock = NSLock()
    private var recordedCalls: [String] = []
    private var recordedAccounts: [Data] = []
    private var recordedCurrencies: [CurrencyId?] = []

    var calls: [String] { locked { recordedCalls } }
    var accounts: [Data] { locked { recordedAccounts } }
    var currencies: [CurrencyId?] { locked { recordedCurrencies } }

    private func locked<R>(_ block: () -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    private func record(_ call: String, _ accountId: Data, currencyId: CurrencyId?? = nil) {
        locked {
            recordedCalls.append(call)
            recordedAccounts.append(accountId)
            if let currencyId { recordedCurrencies.append(currencyId) }
        }
    }

    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks {
        record("staking", accountId)
        return try staking.get()
    }

    func fetchNominationPoolLocks(for accountId: AccountId) async throws -> StakingLocks {
        record("pools", accountId)
        return try pools.get()
    }

    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal {
        record("governance", accountId)
        return try governance.get()
    }

    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal {
        record("crowdloan", accountId)
        return try crowdloan.get()
    }

    func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        record("vesting", accountId, currencyId: .some(currencyId))
        return try vesting.get()
    }

    func fetchTotalLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        record("total", accountId, currencyId: .some(currencyId))
        return 0
    }

    func fetchAssetLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        record("asset", accountId, currencyId: .some(currencyId))
        return 0
    }

    func fetchAssetFrozen(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        record("frozen", accountId, currencyId: .some(currencyId))
        return try frozen.get()
    }

    func fetchAssetBlocked(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        record("blocked", accountId, currencyId: .some(currencyId))
        return try blocked.get()
    }
}

/// Interactor output that records each callback with its value, in arrival order.
final class CovJFinLocksOutput: BalanceLocksDetailInteractorOutput {
    private let lock = NSLock()
    private var recorded: [String] = []
    private var recordedErrors: [Error] = []

    var events: [String] { locked { recorded } }
    var errors: [Error] { locked { recordedErrors } }

    private func locked<R>(_ block: () -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    private func record(_ event: String) { locked { recorded.append(event) } }

    private func record(_ event: String, error: Error) {
        locked {
            recorded.append(event)
            recordedErrors.append(error)
        }
    }

    private func text(_ value: Decimal?) -> String { value.map { "\($0)" } ?? "nil" }

    func didReceiveStakingLocks(_ stakingLocks: StakingLocks?) async { record("staking:\(text(stakingLocks?.total))") }
    func didReceiveNominationPoolLocks(_ nominationPoolLocks: StakingLocks?) async { record("pools:\(text(nominationPoolLocks?.total))") }
    func didReceiveGovernanceLocks(_ balanceLocks: Decimal?) async { record("governance:\(text(balanceLocks))") }
    func didReceiveCrowdloanLocks(_ crowdloanLocks: Decimal?) async { record("crowdloan:\(text(crowdloanLocks))") }
    func didReceiveVestingLocks(_ vestingLocks: Decimal?) async { record("vesting:\(text(vestingLocks))") }
    func didReceiveAssetFrozen(_ frozen: Decimal?) async { record("frozen:\(text(frozen))") }
    func didReceiveAssetBlocked(_ blocked: Decimal?) async { record("blocked:\(text(blocked))") }

    func didReceiveStakingLocksError(_ error: Error) async { record("stakingError", error: error) }
    func didReceiveNominationPoolLocksError(_ error: Error) async { record("poolsError", error: error) }
    func didReceiveGovernanceLocksError(_ error: Error) async { record("governanceError", error: error) }
    func didReceiveCrowdloanLocksError(_ error: Error) async { record("crowdloanError", error: error) }
    func didReceiveVestingLocksError(_ error: Error) async { record("vestingError", error: error) }
    func didReceiveAssetFrozenError(_ error: Error) async { record("frozenError", error: error) }
    func didReceiveAssetBlockedError(_ error: Error) async { record("blockedError", error: error) }
}

final class CovJFinBalanceLocksInteractorTests: XCTestCase {
    func testSetupFetchesEveryCategoryInOrderForTheWalletAccount() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovJFinClaimFixture.ormlChainAsset()
        let fetcher = CovJFinLocksFetcher()
        let output = CovJFinLocksOutput()
        let interactor = BalanceLocksDetailInteractor(wallet: wallet, chainAsset: chainAsset, balanceLocksFetching: fetcher)

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until(timeout: 3) { output.events.count == 7 })
        XCTAssertEqual(output.events, [
            "staking:16", "pools:20", "governance:4", "crowdloan:5", "vesting:6", "frozen:7", "blocked:8"
        ])
        XCTAssertEqual(fetcher.calls, ["staking", "pools", "governance", "crowdloan", "vesting", "frozen", "blocked"])
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        XCTAssertEqual(fetcher.accounts, Array(repeating: accountId, count: 7))
        XCTAssertEqual(fetcher.currencies.count, 3)
        XCTAssertTrue(fetcher.currencies.allSatisfy { $0 == chainAsset.currencyId && $0 != nil })
    }

    func testSetupReportsEachCategoryFailure() {
        let fetcher = CovJFinLocksFetcher()
        fetcher.staking = .failure(CovJError("staking"))
        fetcher.pools = .failure(CovJError("pools"))
        fetcher.governance = .failure(CovJError("governance"))
        fetcher.crowdloan = .failure(CovJError("crowdloan"))
        fetcher.vesting = .failure(CovJError("vesting"))
        fetcher.frozen = .failure(CovJError("frozen"))
        fetcher.blocked = .failure(CovJError("blocked"))
        let output = CovJFinLocksOutput()
        let interactor = BalanceLocksDetailInteractor(
            wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovJFinClaimFixture.plainChainAsset(), balanceLocksFetching: fetcher
        )

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until(timeout: 3) { output.events.count == 7 })
        XCTAssertEqual(output.events, [
            "stakingError", "poolsError", "governanceError", "crowdloanError", "vestingError", "frozenError", "blockedError"
        ])
        XCTAssertEqual(output.errors.compactMap { ($0 as? CovJError)?.message },
                       ["staking", "pools", "governance", "crowdloan", "vesting", "frozen", "blocked"])
        XCTAssertTrue(fetcher.currencies.allSatisfy { $0 == nil })
    }

    func testWalletWithoutAccountSkipsQueriesAndFailsAssetCategories() {
        let fetcher = CovJFinLocksFetcher()
        let output = CovJFinLocksOutput()
        let interactor = BalanceLocksDetailInteractor(
            wallet: CovJFinClaimFixture.walletWithoutAccounts(), chainAsset: CovJFinClaimFixture.plainChainAsset(), balanceLocksFetching: fetcher
        )

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until(timeout: 3) { output.events.count == 3 })
        CovJWait.drain()
        XCTAssertEqual(output.events, ["vestingError", "frozenError", "blockedError"])
        XCTAssertTrue(output.errors.allSatisfy { ($0 as? ChainAccountFetchingError) == .accountNotExists })
        XCTAssertTrue(fetcher.calls.isEmpty)
    }
}
