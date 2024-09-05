import Foundation
import SSFModels
import SSFUtils
import RobinHood
import BigInt

enum BalanceLocksFetchingError: Error {
    case unknownChainAssetType
    case stakingNotFound
    case noDataFound
}

// sourcery: AutoMockable
// sourcery: import = ["SSFModels"]
protocol BalanceLocksFetching {
    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchNominationPoolLocks(for accountId: AccountId) async throws -> StakingLocks
    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal
    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal
    func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
    func fetchTotalLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
    func fetchAssetLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
    func fetchAssetFrozen(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
    func fetchAssetBlocked(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal
}

final class BalanceLocksFetchingDefault {
    private let storageRequestPerformer: StorageRequestPerformer
    private let chainAsset: ChainAsset
    private let crowdloanService: CrowdloanService
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let operationQueue = OperationQueue()

    init(
        storageRequestPerformer: StorageRequestPerformer,
        chainAsset: ChainAsset,
        crowdloanService: CrowdloanService,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    ) {
        self.storageRequestPerformer = storageRequestPerformer
        self.chainAsset = chainAsset
        self.crowdloanService = crowdloanService
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
    }

    private func fetchStakingController(accountId: AccountId) async throws -> AccountId? {
        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let controllerRequest = StakingControllerRequest(accountId: accountIdVariant)

        let controllerAddress: String? = try? await storageRequestPerformer.performSingle(controllerRequest)
        if let controllerAddress {
            return try controllerAddress.toAccountId()
        }

        let controllerAccountId: Data? = try await storageRequestPerformer.performSingle(controllerRequest)
        return controllerAccountId
    }

    private func fetchPoolPendingRewards(for accountId: AccountId) async throws -> BigUInt? {
        let operation = stakingPoolOperationFactory.fetchPendingRewards(accountId: accountId)
        operationQueue.addOperations(operation.allOperations, waitUntilFinished: false)

        return try await withCheckedThrowingContinuation { continuation in
            operation.targetOperation.completionBlock = {
                do {
                    let claimable = try operation.targetOperation.extractNoCancellableResultData()
                    return continuation.resume(with: .success(claimable))
                } catch {
                    return continuation.resume(with: .failure(error))
                }
            }
        }
    }

    private func fetchAssetAccountInfo(for accountId: AccountId, currencyId: CurrencyId?) async throws -> AssetAccountInfo? {
        guard let currencyId else {
            return nil
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let request = AssetsAccountRequest(accountId: accountIdVariant, currencyId: currencyId)
        let assetAccountInfo: AssetAccountInfo? = try await storageRequestPerformer.performSingle(request)
        return assetAccountInfo
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
        guard chainAsset.asset.staking != nil else {
            throw BalanceLocksFetchingError.stakingNotFound
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let ledgerRequest = StakingLedgerRequest(accountId: accountIdVariant)
        let eraRequest = StakingCurrentEraRequest()

        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performSingle(eraRequest)
        async let asyncLedger: StakingLedger? = storageRequestPerformer.performSingle(ledgerRequest)

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
        guard chainAsset.asset.staking != nil else {
            throw BalanceLocksFetchingError.stakingNotFound
        }

        let poolMemberRequest = NominationPoolsPoolMembersRequest(accountId: accountId)
        let eraRequest = StakingCurrentEraRequest()

        async let asyncStakingPoolMember: StakingPoolMember? = storageRequestPerformer.performSingle(poolMemberRequest)
        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performSingle(eraRequest)
        async let claimableResponse = try await fetchPoolPendingRewards(for: accountId)

        let stakingPoolMember = try await asyncStakingPoolMember
        let activeEra = try await asyncActiveEra?.value
        let claimableValue = try await claimableResponse

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

        let claimable = Decimal.fromSubstrateAmount(
            claimableValue.or(.zero),
            precision: precision
        ).or(.zero)

        return StakingLocks(
            staked: staked,
            unstaking: unstaking,
            redeemable: redeemable,
            claimable: claimable
        )
    }

    func fetchGovernanceLocks(for accountId: AccountId) async throws -> Decimal {
        guard chainAsset.isUtility else {
            throw BalanceLocksFetchingError.noDataFound
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let balancesLocksRequest = BalancesLocksRequest(accountId: accountIdVariant)
        let balanceLocks: BalanceLocks? = try await storageRequestPerformer.performSingle(balancesLocksRequest)
        let govLocked = balanceLocks?.first(where: { $0.displayId == "pyconvot" })?.amount
        return Decimal.fromSubstrateAmount(govLocked.or(.zero), precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchCrowdloanLocks(for accountId: AccountId) async throws -> Decimal {
        guard chainAsset.isUtility else {
            throw BalanceLocksFetchingError.noDataFound
        }

        let contributions = try await crowdloanService.fetchContributions(accountId: accountId)
        let totalLocked = contributions.map { $0.value }.map { $0.balance }.reduce(0, +)
        return Decimal.fromSubstrateAmount(totalLocked, precision: Int16(chainAsset.asset.precision)).or(.zero)
    }

    func fetchVestingLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let balancesLocksRequest = BalancesLocksRequest(accountId: accountIdVariant)
        let balanceLocks: BalanceLocks? = try? await storageRequestPerformer.performSingle(balancesLocksRequest)

        let balanceLockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero

        guard let currencyId else {
            return balanceLockedRewardsValue
        }

        let tokensLocksRequest = TokensLocksRequest(accountId: accountIdVariant, currencyId: currencyId)
        let tokenLocks: TokenLocks? = try? await storageRequestPerformer.performSingle(tokensLocksRequest)
        let tokenLockedRewardsValue = tokenLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.map { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        } ?? .zero

        return [balanceLockedRewardsValue, tokenLockedRewardsValue].reduce(0, +)
    }

    func fetchAssetLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        guard let currencyId else {
            return .zero
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let request = AssetsAccountRequest(accountId: accountIdVariant, currencyId: currencyId)
        let assetAccountInfo: AssetAccountInfo? = try await storageRequestPerformer.performSingle(request)
        let locked = assetAccountInfo.flatMap {
            Decimal.fromSubstrateAmount($0.locked, precision: Int16(chainAsset.asset.precision))
        }
        return locked.or(.zero)
    }

    func fetchAssetFrozen(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        let assetAccountInfo = try await fetchAssetAccountInfo(for: accountId, currencyId: currencyId)
        let frozen = assetAccountInfo.flatMap {
            Decimal.fromSubstrateAmount($0.frozen, precision: Int16(chainAsset.asset.precision))
        }
        return frozen.or(.zero)
    }

    func fetchAssetBlocked(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        let assetAccountInfo = try await fetchAssetAccountInfo(for: accountId, currencyId: currencyId)
        let blocked = assetAccountInfo.flatMap {
            Decimal.fromSubstrateAmount($0.blocked, precision: Int16(chainAsset.asset.precision))
        }
        return blocked.or(.zero)
    }
}
