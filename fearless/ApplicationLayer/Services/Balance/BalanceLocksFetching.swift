import Foundation
import SSFModels
import SSFUtils
import RobinHood
import BigInt
import SSFCrypto

enum BalanceLocksFetchingError: Error {
    case unknownChainAssetType
    case stakingNotFound
    case noDataFound
    case noVestingLocksFound
    case noAssetFrozenFound
    case timeout
}

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

        let controllerAddress: String? = try? await storageRequestPerformer.performSingle(controllerRequest, chain: chainAsset.chain)
        if let controllerAddress {
            return try controllerAddress.toAccountId(using: chainAsset.chain.chainFormat)
        }

        let controllerAccountId: Data? = try await storageRequestPerformer.performSingle(controllerRequest, chain: chainAsset.chain)
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
        let assetAccountInfo: AssetAccountInfo? = try await storageRequestPerformer.performSingle(request, chain: chainAsset.chain)
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
        
        var stakingLocksValue: Decimal?
        var nominationPoolLocksValue: Decimal?
        var governanceLocksValue: Decimal?
        var crowdloanLocksValue: Decimal?
        var vestingLocksValue: Decimal?
        
        var errors: [Error] = []
        
        do {
            if chainAsset.asset.staking == nil {
                stakingLocksValue = 0
            } else {
                stakingLocksValue = try await stakingLocks
            }
        } catch {
            errors.append(error)
        }
        
        do {
            if chainAsset.chain.options?.contains(.poolStaking) != true {
                nominationPoolLocksValue = 0
            } else {
                nominationPoolLocksValue = try await nominationPoolLocks
            }
        } catch {
            errors.append(error)
        }
        
        do {
            if chainAsset.isUtility {
                governanceLocksValue = try await governanceLocks
            } else {
                governanceLocksValue = 0
            }
        } catch {
            errors.append(error)
        }
        
        do {
            vestingLocksValue = try await vestingLocks
        } catch {
            errors.append(error)
        }
        
        do {
            if chainAsset.isUtility {
                crowdloanLocksValue = try await crowdloanLocks
            } else {
                crowdloanLocksValue = 0
            }
        } catch {
            errors.append(error)
        }
        
        
        let isTimeoutError: Bool = errors.first { $0 as? JSONRPCEngineError == JSONRPCEngineError.clientCancelled } != nil
        
        guard !isTimeoutError else {
            throw BalanceLocksFetchingError.timeout
        }
        
        
        return [
            stakingLocksValue,
            nominationPoolLocksValue,
            governanceLocksValue,
            crowdloanLocksValue,
            vestingLocksValue
        ].compactMap { $0 }.reduce(0, +)
        
    }

    func fetchStakingLocks(for accountId: AccountId) async throws -> StakingLocks {
        guard chainAsset.asset.staking != nil else {
            throw BalanceLocksFetchingError.stakingNotFound
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let ledgerRequest = StakingLedgerRequest(accountId: accountIdVariant)
        let eraRequest = StakingCurrentEraRequest()

        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performSingle(eraRequest, chain: chainAsset.chain)
        async let asyncLedger: StakingLedger? = storageRequestPerformer.performSingle(ledgerRequest, chain: chainAsset.chain)

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

        async let asyncStakingPoolMember: StakingPoolMember? = storageRequestPerformer.performSingle(poolMemberRequest, chain: chainAsset.chain)
        async let asyncActiveEra: StringScaleMapper<EraIndex>? = storageRequestPerformer.performSingle(eraRequest, chain: chainAsset.chain)
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
        let balanceLocks: BalanceLocks? = try await storageRequestPerformer.performSingle(balancesLocksRequest, chain: chainAsset.chain)
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
        let balanceLocks: BalanceLocks? = try? await storageRequestPerformer.performSingle(balancesLocksRequest, chain: chainAsset.chain)

        let balanceLockedRewardsValue = balanceLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.flatMap { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision))
        }

        guard let currencyId else {
            guard let balanceLockedRewardsValue else {
                throw BalanceLocksFetchingError.noVestingLocksFound
            }
            
            return balanceLockedRewardsValue
        }

        let tokensLocksRequest = TokensLocksRequest(accountId: accountIdVariant, currencyId: currencyId)
        let tokenLocks: TokenLocks? = try? await storageRequestPerformer.performSingle(tokensLocksRequest, chain: chainAsset.chain)
        let tokenLockedRewardsValue = tokenLocks?.first { $0.lockType?.lowercased().contains("vest") == true }.flatMap { lock in
            Decimal.fromSubstrateAmount(lock.amount, precision: Int16(chainAsset.asset.precision))
        }

        let values = [balanceLockedRewardsValue, tokenLockedRewardsValue].compactMap { $0 }
        guard values.first != nil else {
            throw BalanceLocksFetchingError.noVestingLocksFound
        }
        
        return values.reduce(0, +)
    }

    func fetchAssetLocks(for accountId: AccountId, currencyId: CurrencyId?) async throws -> Decimal {
        guard let currencyId else {
            throw BalanceLocksFetchingError.noAssetFrozenFound
        }

        let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
        let request = AssetsAccountRequest(accountId: accountIdVariant, currencyId: currencyId)
        let assetAccountInfo: AssetAccountInfo? = try await storageRequestPerformer.performSingle(request, chain: chainAsset.chain)
        let locked = assetAccountInfo.flatMap {
            Decimal.fromSubstrateAmount($0.locked, precision: Int16(chainAsset.asset.precision))
        }
        
        guard let locked else {
            throw BalanceLocksFetchingError.noAssetFrozenFound
        }
        
        return locked
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
