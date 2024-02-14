import Foundation
import SSFModels
import SSFUtils
import RobinHood

enum BalanceLocksFetchingError: Error {
    case unknownChainAssetType
}

protocol BalanceLocksFetching {
    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchNominationPoolLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal
    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal
    func fetchVestingLocks(for accountId: AccountId) async throws -> Decimal
}

final class BalanceLocksFetchingDefault {
    private let storageRequestPerformer: StorageRequestPerformer
    private let chainAsset: ChainAsset
    private let crowdloanService: CrowdloanService

    init(
        storageRequestPerformer: StorageRequestPerformer,
        chainAsset: ChainAsset,
        crowdloanService: CrowdloanService
    ) {
        self.storageRequestPerformer = storageRequestPerformer
        self.chainAsset = chainAsset
        self.crowdloanService = crowdloanService
    }
}

extension BalanceLocksFetchingDefault: BalanceLocksFetching {
    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks {
        let ledgerRequest = StakingLedgerRequest(accountId: accountId)
        let eraRequest = StakingCurrentEraRequest()

        let ledger: StakingLedger? = try await storageRequestPerformer.performRequest(ledgerRequest)
        let activeEra: EraIndex? = try await storageRequestPerformer.performRequest(eraRequest)

        let precision = Int16(chainAsset.asset.precision)

        let active = ledger?.active
        let staked = Decimal.fromSubstrateAmount(
            active.or(.zero),
            precision: precision
        ).or(.zero)

        let unstakingValue = activeEra.map {
            ledger?
                .unbondings(inEra: $0)
                .map { $0.value }
                .reduce(0, +)
        }.or(.zero)

        let unstaking = Decimal.fromSubstrateAmount(
            unstakingValue.or(.zero),
            precision: precision
        ).or(.zero)

        let redeemableValue = activeEra.map {
            ledger?.redeemable(inEra: $0)
        }.or(.zero)

        let redeemable = Decimal.fromSubstrateAmount(
            redeemableValue.or(.zero),
            precision: precision
        ).or(.zero)

        return StakingLocks(
            staked: staked,
            unstaking: unstaking,
            redeemable: redeemable,
            claimable: nil
        )
    }

    func fetchNominationPoolLocks(for accountId: AccountId) async throws -> StakingLocks {
        let poolMemberRequest = NominationPoolsPoolMembersRequest(accountId: accountId)
        let eraRequest = StakingCurrentEraRequest()

        let stakingPoolMember: StakingPoolMember? = try await storageRequestPerformer.performRequest(poolMemberRequest)
        let activeEra: EraIndex? = try await storageRequestPerformer.performRequest(eraRequest)

        let precision = Int16(chainAsset.asset.precision)

        let pointsValue = stakingPoolMember?.points
        let staked = Decimal.fromSubstrateAmount(
            pointsValue.or(.zero),
            precision: precision
        ).or(.zero)

        let unstakingValue = activeEra.map { stakingPoolMember?
            .unbondings(inEra: $0)
            .map { $0.value }
            .reduce(0, +)
        }.or(.zero)
        let unstaking = Decimal.fromSubstrateAmount(
            unstakingValue.or(.zero),
            precision: precision
        ).or(.zero)

        let redeemableValue = activeEra.map {
            stakingPoolMember?.redeemable(inEra: $0)
        }.or(.zero)
        let redeemable = Decimal.fromSubstrateAmount(
            redeemableValue.or(.zero),
            precision: precision
        ).or(.zero)

        return StakingLocks(
            staked: staked,
            unstaking: unstaking,
            redeemable: redeemable,
            claimable: nil
        )
    }

    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal {
        let request = BalancesLocksRequest(accountId: accountId)
        let balanceLocks: BalanceLocks? = try await storageRequestPerformer.performRequest(request)
        let govLocked = balanceLocks?.first(where: { $0.displayId == "pyconvot" })?.amount
        return Decimal.fromSubstrateAmount(govLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal {
        let contributions = try await crowdloanService.fetchContributions(accountId: accountId)
        let totalLocked = contributions.map { $0.value }.map { $0.balance }.reduce(0, +)
        return Decimal.fromSubstrateAmount(totalLocked, precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchVestingLocks(for accountId: AccountId) async throws -> Decimal {
        let vestingRequest = VestingVestingRequest(accountId: accountId)
        let vestingScheduleRequest = VestingSchedulesRequest(accountId: accountId)

        let vestings: [VestingVesting]? = try? await storageRequestPerformer.performRequest(vestingRequest)
        let vestingSchedules: [VestingSchedule]? = try? await storageRequestPerformer.performRequest(vestingScheduleRequest)

        let vestingLocked = (vestings?.first)?.map { vesting in
            let lockedValue = Decimal.fromSubstrateAmount(vesting.locked ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return lockedValue
        } ?? .zero

        let vestingScheduleLocked = (vestingSchedules?.first)?.map { vestingSchedule in
            let periodsDecimal = Decimal(vestingSchedule.periodCount ?? 0)
            let perPeriodDecimal = Decimal.fromSubstrateAmount(vestingSchedule.perPeriod ?? .zero, precision: Int16(chainAsset.asset.precision)) ?? .zero

            return periodsDecimal * perPeriodDecimal
        } ?? .zero

        return vestingScheduleLocked + vestingLocked
    }
}
