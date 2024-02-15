import Foundation
import SSFModels
import SSFUtils
import RobinHood

enum BalanceLocksFetchingError: Error {
    case unknownChainAssetType
    case stakingNotFound
}

protocol BalanceLocksFetching {
    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchNominationPoolLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal
    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal
    func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
    func fetchTotalLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
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

    private func fetchStakingController(accountId: AccountId) async throws -> AccountId? {
        let controllerRequest = StakingControllerRequestBuilder().buildRequest(for: chainAsset, accountId: accountId)
        let controllerAddress: String? = try? await storageRequestPerformer.performRequest(controllerRequest)
        if let controllerAddress {
            return try controllerAddress.toAccountId()
        }

        let controllerAccountId: Data? = try await storageRequestPerformer.performRequest(controllerRequest)
        return controllerAccountId
    }
}

extension BalanceLocksFetchingDefault: BalanceLocksFetching {
    func fetchTotalLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        async let stakingLocks = fetchStakingLocks(for: accountId).total
        async let nominationPoolLocks = fetchNominationPoolLocks(for: accountId).total
        async let governanceLocks = fetchGovernanceLocks(for: accountId)
        async let crowdloanLocks = fetchCrowdloanLocks(for: accountId)
        async let vestingLocks = fetchVestingLocks(for: accountId, currencyId: currencyId)

        return await [
            (try? stakingLocks).or(.zero),
            (try? nominationPoolLocks).or(.zero),
            (try? governanceLocks).or(.zero),
            (try? crowdloanLocks).or(.zero),
            (try? vestingLocks).or(.zero)
        ].reduce(0, +)
    }

    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks {
        let controller = try await fetchStakingController(accountId: accountId)
        guard let controller else {
            throw BalanceLocksFetchingError.stakingNotFound
        }

        let ledgerRequest = StakingLedgerRequestBuilder().buildRequest(for: chainAsset, accountId: controller)
        let eraRequest = StakingCurrentEraRequest()

        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performRequest(eraRequest)
        async let asyncLedger: StakingLedger? = storageRequestPerformer.performRequest(ledgerRequest)

        let ledger = try await asyncLedger
        let activeEra = try await asyncActiveEra?.value

        let precision = Int16(chainAsset.asset.precision)

        let staked = Decimal.fromSubstrateAmount(
            (ledger?.active).or(.zero),
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

        async let asyncStakingPoolMember: StakingPoolMember? = storageRequestPerformer.performRequest(poolMemberRequest)
        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performRequest(eraRequest)

        let stakingPoolMember = try await asyncStakingPoolMember
        let activeEra = try await asyncActiveEra?.value

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
        let balancesLocksRequest = BalanceLocksRequestBuilder().buildRequest(for: chainAsset, accountId: accountId)
        let balanceLocks: BalanceLocks? = try await storageRequestPerformer.performRequest(balancesLocksRequest)
        let govLocked = balanceLocks?.first(where: { $0.displayId == "pyconvot" })?.amount
        return Decimal.fromSubstrateAmount(govLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal {
        let contributions = try await crowdloanService.fetchContributions(accountId: accountId)
        let totalLocked = contributions.map { $0.value }.map { $0.balance }.reduce(0, +)
        return Decimal.fromSubstrateAmount(totalLocked, precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        let balancesLocksRequest = BalanceLocksRequestBuilder().buildRequest(for: chainAsset, accountId: accountId)
        let balanceLocks: BalanceLocks? = try? await storageRequestPerformer.performRequest(balancesLocksRequest)

        let balanceLockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero

        guard let currencyId else {
            return balanceLockedRewardsValue
        }

        let tokensLocksRequest = TokensLocksRequestBuilder().buildRequest(for: chainAsset, accountId: accountId, currencyId: currencyId)
        let tokenLocks: TokenLocks? = try? await storageRequestPerformer.performRequest(tokensLocksRequest)
        let tokenLockedRewardsValue = tokenLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero

        return [balanceLockedRewardsValue, tokenLockedRewardsValue].reduce(0, +)
    }
}
