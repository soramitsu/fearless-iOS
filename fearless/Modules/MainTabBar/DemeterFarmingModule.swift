import BigInt
import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils
import UIKit

enum DemeterConstants {
    static let moduleName = "DemeterFarmingPlatform"
    static let blocksPerYear = Decimal(5_256_000)
    static let fixedPrecision: UInt16 = 18
}

struct DemeterPoolIdentity: Hashable {
    let baseAssetId: String
    let poolAssetId: String
    let rewardAssetId: String
    let isFarm: Bool
}

struct DemeterPool: Equatable {
    let identity: DemeterPoolIdentity
    let multiplier: String
    let depositFee: String
    let isCore: Bool
    let totalTokensInPool: String
    let rewards: String
    let rewardsToBeDistributed: String
    let isRemoved: Bool
}

struct DemeterRewardToken: Equatable {
    let assetId: String
    let farmsTotalMultiplier: String
    let stakingTotalMultiplier: String
    let tokenPerBlock: String
    let farmsAllocation: String
    let stakingAllocation: String
}

struct DemeterAccountPosition: Equatable {
    let identity: DemeterPoolIdentity
    let pooledTokens: String
    let rewards: String

    var isActive: Bool {
        (BigUInt(pooledTokens, radix: 10) ?? .zero) > .zero ||
            (BigUInt(rewards, radix: 10) ?? .zero) > .zero
    }
}

struct DemeterRuntimeCapabilities: Equatable {
    let palletAvailable: Bool
    let storage: Set<String>
    let calls: Set<String>

    private func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "")
    }

    func hasStorage(_ name: String) -> Bool {
        storage.contains { normalized($0) == normalized(name) }
    }

    func hasCall(_ name: String) -> Bool {
        calls.contains { normalized($0) == normalized(name) }
    }

    func resolvedCallName(_ name: String) -> String? {
        calls.first { normalized($0) == normalized(name) }
    }

    var canBrowse: Bool {
        palletAvailable && hasStorage("Pools") && hasStorage("TokenInfos")
    }

    var canMutate: Bool {
        hasCall("deposit") && hasCall("withdraw") && hasCall("getRewards")
    }

    var unavailableReason: String? {
        if !palletAvailable { return "The connected SORA runtime does not expose Demeter Farming." }
        if !canBrowse { return "Demeter pool storage is unavailable on this SORA runtime." }
        if !canMutate { return "Pool discovery is available, but this runtime cannot deposit, withdraw, or claim." }
        return nil
    }
}

struct DemeterSnapshot {
    let pools: [DemeterPool]
    let rewardTokens: [String: DemeterRewardToken]
    let positions: [DemeterAccountPosition]
    let capabilities: DemeterRuntimeCapabilities
}

protocol DemeterRuntimeSnapshotProviding {
    func snapshot() async throws -> DemeterSnapshot
}

private struct DemeterStoredPool: Decodable {
    let multiplier: BigUInt
    let depositFee: BigUInt
    let isCore: Bool
    let isFarm: Bool
    let totalTokensInPool: BigUInt
    let rewards: BigUInt
    let rewardsToBeDistributed: BigUInt
    let isRemoved: Bool
    let baseAsset: SoraAssetId

    private enum CodingKeys: String, CodingKey {
        case multiplier, depositFee, isCore, isFarm, totalTokensInPool
        case rewards, rewardsToBeDistributed, isRemoved, baseAsset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        multiplier = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .multiplier).value
        depositFee = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .depositFee).value
        isCore = try container.decode(Bool.self, forKey: .isCore)
        isFarm = try container.decode(Bool.self, forKey: .isFarm)
        totalTokensInPool = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .totalTokensInPool).value
        rewards = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .rewards).value
        rewardsToBeDistributed = try container.decode(
            StringScaleMapper<BigUInt>.self,
            forKey: .rewardsToBeDistributed
        ).value
        isRemoved = try container.decode(Bool.self, forKey: .isRemoved)
        baseAsset = try container.decode(SoraAssetId.self, forKey: .baseAsset)
    }
}

private struct DemeterStoredRewardToken: Decodable {
    let farmsTotalMultiplier: BigUInt
    let stakingTotalMultiplier: BigUInt
    let tokenPerBlock: BigUInt
    let farmsAllocation: BigUInt
    let stakingAllocation: BigUInt

    private enum CodingKeys: String, CodingKey {
        case farmsTotalMultiplier, stakingTotalMultiplier, tokenPerBlock
        case farmsAllocation, stakingAllocation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        farmsTotalMultiplier = try container.decode(
            StringScaleMapper<BigUInt>.self,
            forKey: .farmsTotalMultiplier
        ).value
        stakingTotalMultiplier = try container.decode(
            StringScaleMapper<BigUInt>.self,
            forKey: .stakingTotalMultiplier
        ).value
        tokenPerBlock = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .tokenPerBlock).value
        farmsAllocation = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .farmsAllocation).value
        stakingAllocation = try container.decode(
            StringScaleMapper<BigUInt>.self,
            forKey: .stakingAllocation
        ).value
    }
}

private struct DemeterStoredUserInfo: Decodable {
    let baseAsset: SoraAssetId
    let poolAsset: SoraAssetId
    let rewardAsset: SoraAssetId
    let isFarm: Bool
    let pooledTokens: BigUInt
    let rewards: BigUInt

    private enum CodingKeys: String, CodingKey {
        case baseAsset, poolAsset, rewardAsset, isFarm, pooledTokens, rewards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseAsset = try container.decode(SoraAssetId.self, forKey: .baseAsset)
        poolAsset = try container.decode(SoraAssetId.self, forKey: .poolAsset)
        rewardAsset = try container.decode(SoraAssetId.self, forKey: .rewardAsset)
        isFarm = try container.decode(Bool.self, forKey: .isFarm)
        pooledTokens = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .pooledTokens).value
        rewards = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .rewards).value
    }
}

final class DemeterRuntimeService: DemeterRuntimeSnapshotProviding {
    let wallet: MetaAccountModel
    let chain: ChainModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let storageFactory: AsyncStorageRequestFactory

    init?(
        wallet: MetaAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        storageFactory: AsyncStorageRequestFactory = AsyncStorageRequestDefault()
    ) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
              let connection = chainRegistry.getConnection(for: chain.chainId) else { return nil }
        self.wallet = wallet
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.storageFactory = storageFactory
    }

    func snapshot() async throws -> DemeterSnapshot {
        let factory = try await runtimeService.fetchCoderFactory()
        guard let module = factory.metadata.modules.first(where: {
            $0.name.caseInsensitiveCompare(DemeterConstants.moduleName) == .orderedSame
        }) else {
            return DemeterSnapshot(
                pools: [],
                rewardTokens: [:],
                positions: [],
                capabilities: DemeterRuntimeCapabilities(palletAvailable: false, storage: [], calls: [])
            )
        }

        var storage = Set<String>()
        ["Pools", "TokenInfos", "UserInfos"].forEach { item in
            if factory.metadata.getStorageMetadata(in: module.name, storageName: item) != nil {
                storage.insert(item)
            }
        }
        var calls = Set<String>()
        if let metadataCalls = try? module.calls(using: factory.metadata.schemaResolver) {
            calls.formUnion(metadataCalls.map(\.name))
        }
        let capabilities = DemeterRuntimeCapabilities(
            palletAvailable: true,
            storage: storage,
            calls: calls
        )
        guard capabilities.canBrowse else {
            return DemeterSnapshot(pools: [], rewardTokens: [:], positions: [], capabilities: capabilities)
        }

        let hasUserInfoStorage = storage.contains("UserInfos")
        async let pools = fetchPools(factory: factory, moduleName: module.name)
        async let tokens = fetchRewardTokens(factory: factory, moduleName: module.name)
        async let positions = fetchPositions(factory: factory, hasStorage: hasUserInfoStorage)
        let values = try await(pools, tokens, positions)
        return DemeterSnapshot(
            pools: values.0,
            rewardTokens: values.1,
            positions: values.2,
            capabilities: capabilities
        )
    }

    private func fetchPools(
        factory: RuntimeCoderFactoryProtocol,
        moduleName: String
    ) async throws -> [DemeterPool] {
        let key = try StorageKeyFactory().createStorageKey(moduleName: moduleName, storageName: "Pools")
        let responses: [StorageResponse<[DemeterStoredPool]>] = try await storageFactory.queryItemsByPrefix(
            engine: connection,
            keys: [key],
            factory: factory,
            storagePath: .demeterPools
        )
        return responses.flatMap { response -> [DemeterPool] in
            guard response.key.count >= 64,
                  let values = response.value else { return [] }
            let identifiers = response.key.suffix(64)
            let poolAssetId = Data(identifiers.prefix(32)).toHex(includePrefix: true)
            let rewardAssetId = Data(identifiers.suffix(32)).toHex(includePrefix: true)
            return values.map { value in
                DemeterPool(
                    identity: DemeterPoolIdentity(
                        baseAssetId: value.baseAsset.value,
                        poolAssetId: poolAssetId,
                        rewardAssetId: rewardAssetId,
                        isFarm: value.isFarm
                    ),
                    multiplier: value.multiplier.description,
                    depositFee: value.depositFee.description,
                    isCore: value.isCore,
                    totalTokensInPool: value.totalTokensInPool.description,
                    rewards: value.rewards.description,
                    rewardsToBeDistributed: value.rewardsToBeDistributed.description,
                    isRemoved: value.isRemoved
                )
            }
        }
    }

    private func fetchRewardTokens(
        factory: RuntimeCoderFactoryProtocol,
        moduleName: String
    ) async throws -> [String: DemeterRewardToken] {
        let key = try StorageKeyFactory().createStorageKey(moduleName: moduleName, storageName: "TokenInfos")
        let responses: [StorageResponse<DemeterStoredRewardToken>] = try await storageFactory.queryItemsByPrefix(
            engine: connection,
            keys: [key],
            factory: factory,
            storagePath: .demeterTokenInfos
        )
        return Dictionary(uniqueKeysWithValues: responses.compactMap { response in
            guard response.key.count >= 32, let value = response.value else { return nil }
            let assetId = Data(response.key.suffix(32)).toHex(includePrefix: true)
            return (
                assetId.lowercased(),
                DemeterRewardToken(
                    assetId: assetId,
                    farmsTotalMultiplier: value.farmsTotalMultiplier.description,
                    stakingTotalMultiplier: value.stakingTotalMultiplier.description,
                    tokenPerBlock: value.tokenPerBlock.description,
                    farmsAllocation: value.farmsAllocation.description,
                    stakingAllocation: value.stakingAllocation.description
                )
            )
        })
    }

    private func fetchPositions(
        factory: RuntimeCoderFactoryProtocol,
        hasStorage: Bool
    ) async throws -> [DemeterAccountPosition] {
        guard hasStorage,
              let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else { return [] }
        let responses: [StorageResponse<[DemeterStoredUserInfo]>] = try await storageFactory.queryItems(
            engine: connection,
            keyParams: [accountId],
            factory: factory,
            storagePath: .demeterUserInfos
        )
        return responses.compactMap(\.value).flatMap { values in
            values.map { value in
                DemeterAccountPosition(
                    identity: DemeterPoolIdentity(
                        baseAssetId: value.baseAsset.value,
                        poolAssetId: value.poolAsset.value,
                        rewardAssetId: value.rewardAsset.value,
                        isFarm: value.isFarm
                    ),
                    pooledTokens: value.pooledTokens.description,
                    rewards: value.rewards.description
                )
            }
        }
    }
}

enum DemeterMutation {
    case deposit(pool: DemeterPool, amount: String)
    case withdraw(pool: DemeterPool, amount: String)
    case claim(pool: DemeterPool)
}

struct DemeterDepositCall: Codable {
    let baseAsset: SoraAssetId
    let poolAsset: SoraAssetId
    let rewardAsset: SoraAssetId
    let isFarm: Bool
    let pooledTokens: String

    enum CodingKeys: String, CodingKey {
        case baseAsset = "base_asset"
        case poolAsset = "pool_asset"
        case rewardAsset = "reward_asset"
        case isFarm = "is_farm"
        case pooledTokens = "pooled_tokens"
    }
}

struct DemeterWithdrawCall: Codable {
    let baseAsset: SoraAssetId
    let poolAsset: SoraAssetId
    let rewardAsset: SoraAssetId
    let pooledTokens: String
    let isFarm: Bool

    enum CodingKeys: String, CodingKey {
        case baseAsset = "base_asset"
        case poolAsset = "pool_asset"
        case rewardAsset = "reward_asset"
        case pooledTokens = "pooled_tokens"
        case isFarm = "is_farm"
    }
}

struct DemeterClaimCall: Codable {
    let baseAsset: SoraAssetId
    let poolAsset: SoraAssetId
    let rewardAsset: SoraAssetId
    let isFarm: Bool

    enum CodingKeys: String, CodingKey {
        case baseAsset = "base_asset"
        case poolAsset = "pool_asset"
        case rewardAsset = "reward_asset"
        case isFarm = "is_farm"
    }
}

private extension DemeterPoolIdentity {
    func isSameRuntimeIdentity(as other: DemeterPoolIdentity) -> Bool {
        baseAssetId.caseInsensitiveCompare(other.baseAssetId) == .orderedSame &&
            poolAssetId.caseInsensitiveCompare(other.poolAssetId) == .orderedSame &&
            rewardAssetId.caseInsensitiveCompare(other.rewardAssetId) == .orderedSame &&
            isFarm == other.isFarm
    }
}

private extension DemeterMutation {
    var pool: DemeterPool {
        switch self {
        case let .deposit(pool, _), let .withdraw(pool, _), let .claim(pool):
            return pool
        }
    }

    var requiredCallName: String {
        switch self {
        case .deposit: return "deposit"
        case .withdraw: return "withdraw"
        case .claim: return "getRewards"
        }
    }

    func replacingPool(_ pool: DemeterPool) -> DemeterMutation {
        switch self {
        case let .deposit(_, amount): return .deposit(pool: pool, amount: amount)
        case let .withdraw(_, amount): return .withdraw(pool: pool, amount: amount)
        case .claim: return .claim(pool: pool)
        }
    }
}

enum DemeterSubmissionError: LocalizedError, Equatable {
    case runtimeUnavailable
    case signerUnavailable
    case selectedWalletChanged
    case runtimeCallUnavailable
    case poolUnavailable
    case poolClosed
    case invalidAmount
    case positionUnavailable
    case insufficientPosition
    case claimUnavailable
    case balanceUnavailable
    case insufficientAsset
    case insufficientFee

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The authoritative SORA Demeter runtime is unavailable."
        case .signerUnavailable:
            return "A local SORA signing key is required. Watch-only and unsupported external signing cannot submit this action."
        case .selectedWalletChanged:
            return "The selected wallet changed. Review the Demeter action again."
        case .runtimeCallUnavailable:
            return "This action is unavailable in the current SORA Demeter runtime."
        case .poolUnavailable:
            return "The exact Demeter pool is unavailable in the current SORA runtime."
        case .poolClosed:
            return "This Demeter pool no longer accepts deposits."
        case .invalidAmount:
            return "Enter a positive Demeter amount."
        case .positionUnavailable:
            return "The authoritative Demeter position is unavailable for this pool and account."
        case .insufficientPosition:
            return "The authoritative Demeter position is smaller than this withdrawal."
        case .claimUnavailable:
            return "The authoritative Demeter position has no rewards to claim."
        case .balanceUnavailable:
            return "The exact pool-asset or XOR balance is unavailable. Refresh SORA before submitting."
        case .insufficientAsset:
            return "The current spendable pool-asset balance is insufficient for this deposit."
        case .insufficientFee:
            return "The current spendable XOR balance is insufficient for the exact network fee."
        }
    }
}

struct DemeterAuthoritativeBalances: Equatable {
    let poolAssetKey: AssetKey?
    let feeAssetKey: AssetKey?
    let poolAssetSpendable: BigUInt?
    let feeSpendable: BigUInt?
}

protocol DemeterAuthoritativeBalanceProviding {
    func balances(for poolIdentity: DemeterPoolIdentity) async -> DemeterAuthoritativeBalances
}

final class DemeterAuthoritativeBalanceProvider: DemeterAuthoritativeBalanceProviding {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let accountInfoRemoteService: AccountInfoRemoteService

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        accountInfoRemoteService: AccountInfoRemoteService? = nil
    ) {
        self.wallet = wallet
        self.chain = chain
        if let accountInfoRemoteService {
            self.accountInfoRemoteService = accountInfoRemoteService
        } else {
            let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
            self.accountInfoRemoteService = AccountInfoRemoteServiceDefault(
                storagePerformer: storagePerformer
            )
        }
    }

    func balances(for poolIdentity: DemeterPoolIdentity) async -> DemeterAuthoritativeBalances {
        let poolMatches = chain.chainAssets.filter {
            $0.asset.currencyId?.caseInsensitiveCompare(poolIdentity.poolAssetId) == .orderedSame
        }
        let feeMatches = chain.chainAssets.filter {
            $0.asset.currencyId?.caseInsensitiveCompare(PolkamarktConstants.feeAssetId) == .orderedSame
        }
        let poolAsset = poolMatches.count == 1 ? poolMatches[0] : nil
        let feeAsset = feeMatches.count == 1 ? feeMatches[0] : nil

        guard wallet.fetch(for: chain.accountRequest()) != nil,
              let feeAsset else {
            return DemeterAuthoritativeBalances(
                poolAssetKey: poolAsset?.assetKey,
                feeAssetKey: feeAsset?.assetKey,
                poolAssetSpendable: nil,
                feeSpendable: nil
            )
        }

        // Submission authorization always reads the runtime-backed account
        // service. Portfolio cache values and symbol matches are never used.
        let accountInfos = try? await accountInfoRemoteService.fetchAccountInfos(
            for: chain,
            wallet: wallet
        )
        let poolInfo: AccountInfo? = poolAsset.flatMap { asset in
            accountInfos.flatMap { $0[asset.chainAssetId] ?? nil }
        }
        let feeInfo: AccountInfo? = accountInfos.flatMap {
            $0[feeAsset.chainAssetId] ?? nil
        }
        return DemeterAuthoritativeBalances(
            poolAssetKey: poolAsset?.assetKey,
            feeAssetKey: feeAsset.assetKey,
            poolAssetSpendable: poolInfo?.data.sendAvailable,
            feeSpendable: feeInfo?.data.sendAvailable
        )
    }
}

enum DemeterMutationBoundaryValidator {
    static func bind(
        _ mutation: DemeterMutation,
        to snapshot: DemeterSnapshot
    ) throws -> DemeterMutation {
        guard snapshot.capabilities.canBrowse else {
            throw DemeterSubmissionError.runtimeUnavailable
        }
        guard snapshot.capabilities.resolvedCallName(mutation.requiredCallName) != nil else {
            throw DemeterSubmissionError.runtimeCallUnavailable
        }

        let matchingPools = snapshot.pools.filter {
            $0.identity.isSameRuntimeIdentity(as: mutation.pool.identity)
        }
        guard matchingPools.count == 1, let currentPool = matchingPools.first else {
            throw DemeterSubmissionError.poolUnavailable
        }

        switch mutation {
        case let .deposit(_, amount):
            guard let amount = BigUInt(amount, radix: 10), amount > .zero else {
                throw DemeterSubmissionError.invalidAmount
            }
            guard !currentPool.isRemoved else {
                throw DemeterSubmissionError.poolClosed
            }
        case let .withdraw(_, amount):
            guard let amount = BigUInt(amount, radix: 10), amount > .zero else {
                throw DemeterSubmissionError.invalidAmount
            }
            let positions = snapshot.positions.filter {
                $0.identity.isSameRuntimeIdentity(as: currentPool.identity)
            }
            guard positions.count == 1,
                  let pooled = positions.first.flatMap({ BigUInt($0.pooledTokens, radix: 10) }) else {
                throw DemeterSubmissionError.positionUnavailable
            }
            guard pooled >= amount else {
                throw DemeterSubmissionError.insufficientPosition
            }
        case .claim:
            let positions = snapshot.positions.filter {
                $0.identity.isSameRuntimeIdentity(as: currentPool.identity)
            }
            guard positions.count == 1,
                  let rewards = positions.first.flatMap({ BigUInt($0.rewards, radix: 10) }) else {
                throw DemeterSubmissionError.positionUnavailable
            }
            guard rewards > .zero else {
                throw DemeterSubmissionError.claimUnavailable
            }
        }

        return mutation.replacingPool(currentPool)
    }

    static func validate(
        _ mutation: DemeterMutation,
        snapshot: DemeterSnapshot,
        balances: DemeterAuthoritativeBalances,
        requiredFee: BigUInt
    ) throws -> DemeterMutation {
        guard requiredFee > .zero else {
            throw DemeterSubmissionError.runtimeUnavailable
        }
        let boundMutation = try bind(mutation, to: snapshot)
        guard let feeKey = balances.feeAssetKey,
              feeKey.chainId.caseInsensitiveCompare(PolkamarktConstants.soraChainId) == .orderedSame,
              feeKey.assetId.caseInsensitiveCompare(PolkamarktConstants.feeAssetId) == .orderedSame,
              let feeSpendable = balances.feeSpendable else {
            throw DemeterSubmissionError.balanceUnavailable
        }

        switch boundMutation {
        case let .deposit(pool, amountString):
            guard let poolKey = balances.poolAssetKey,
                  poolKey.chainId.caseInsensitiveCompare(PolkamarktConstants.soraChainId) == .orderedSame,
                  poolKey.assetId.caseInsensitiveCompare(pool.identity.poolAssetId) == .orderedSame,
                  let poolSpendable = balances.poolAssetSpendable,
                  let amount = BigUInt(amountString, radix: 10) else {
                throw DemeterSubmissionError.balanceUnavailable
            }
            if pool.identity.poolAssetId.caseInsensitiveCompare(PolkamarktConstants.feeAssetId) == .orderedSame {
                guard poolSpendable >= amount + requiredFee else {
                    throw DemeterSubmissionError.insufficientAsset
                }
            } else {
                guard poolSpendable >= amount else {
                    throw DemeterSubmissionError.insufficientAsset
                }
                guard feeSpendable >= requiredFee else {
                    throw DemeterSubmissionError.insufficientFee
                }
            }
        case .withdraw, .claim:
            guard feeSpendable >= requiredFee else {
                throw DemeterSubmissionError.insufficientFee
            }
        }

        return boundMutation
    }
}

protocol DemeterMutationCallBuilding {
    func builder(
        for mutation: DemeterMutation,
        capabilities: DemeterRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure
}

struct DemeterMutationCallBuilder: DemeterMutationCallBuilding {
    func builder(
        for mutation: DemeterMutation,
        capabilities: DemeterRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure {
        guard capabilities.palletAvailable else {
            throw DemeterSubmissionError.runtimeUnavailable
        }

        switch mutation {
        case let .deposit(pool, amount):
            guard !pool.isRemoved,
                  BigUInt(amount, radix: 10).map({ $0 > .zero }) == true,
                  let name = capabilities.resolvedCallName("deposit") else {
                throw DemeterSubmissionError.runtimeCallUnavailable
            }
            let call = RuntimeCall(
                moduleName: DemeterConstants.moduleName,
                callName: name,
                args: DemeterDepositCall(
                    baseAsset: SoraAssetId(wrappedValue: pool.identity.baseAssetId),
                    poolAsset: SoraAssetId(wrappedValue: pool.identity.poolAssetId),
                    rewardAsset: SoraAssetId(wrappedValue: pool.identity.rewardAssetId),
                    isFarm: pool.identity.isFarm,
                    pooledTokens: amount
                )
            )
            return { try $0.adding(call: call) }
        case let .withdraw(pool, amount):
            guard BigUInt(amount, radix: 10).map({ $0 > .zero }) == true,
                  let name = capabilities.resolvedCallName("withdraw") else {
                throw DemeterSubmissionError.runtimeCallUnavailable
            }
            let call = RuntimeCall(
                moduleName: DemeterConstants.moduleName,
                callName: name,
                args: DemeterWithdrawCall(
                    baseAsset: SoraAssetId(wrappedValue: pool.identity.baseAssetId),
                    poolAsset: SoraAssetId(wrappedValue: pool.identity.poolAssetId),
                    rewardAsset: SoraAssetId(wrappedValue: pool.identity.rewardAssetId),
                    pooledTokens: amount,
                    isFarm: pool.identity.isFarm
                )
            )
            return { try $0.adding(call: call) }
        case let .claim(pool):
            guard let name = capabilities.resolvedCallName("getRewards") else {
                throw DemeterSubmissionError.runtimeCallUnavailable
            }
            let call = RuntimeCall(
                moduleName: DemeterConstants.moduleName,
                callName: name,
                args: DemeterClaimCall(
                    baseAsset: SoraAssetId(wrappedValue: pool.identity.baseAssetId),
                    poolAsset: SoraAssetId(wrappedValue: pool.identity.poolAssetId),
                    rewardAsset: SoraAssetId(wrappedValue: pool.identity.rewardAssetId),
                    isFarm: pool.identity.isFarm
                )
            )
            return { try $0.adding(call: call) }
        }
    }
}

protocol DemeterMutationExtrinsicExecuting: AnyObject {
    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo
    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String
}

final class DemeterMutationExtrinsicExecutor: DemeterMutationExtrinsicExecuting {
    private let service: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol

    init(service: ExtrinsicServiceProtocol, signer: SigningWrapperProtocol) {
        self.service = service
        self.signer = signer
    }

    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        try await withCheckedThrowingContinuation { continuation in
            service.estimateFee(builder, runningIn: .main) { continuation.resume(with: $0) }
        }
    }

    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.submit(builder, signer: signer, runningIn: .main) { continuation.resume(with: $0) }
        }
    }
}

struct DemeterAuthorizedSubmission {
    let builder: ExtrinsicBuilderClosure
    let executor: DemeterMutationExtrinsicExecuting
    let finalGuard: () throws -> Void
}

protocol DemeterMutationSubmissionAuthorizing {
    func authorize(_ mutation: DemeterMutation) async throws -> DemeterAuthorizedSubmission
}

final class DemeterMutationSubmissionAuthorizer: DemeterMutationSubmissionAuthorizing {
    private struct Context {
        let wallet: MetaAccountModel
        let chain: ChainModel
        let account: ChainAccountResponse
        let runtime: RuntimeProviderProtocol
        let connection: JSONRPCEngine
        let snapshotProvider: DemeterRuntimeSnapshotProviding
        let balanceProvider: DemeterAuthoritativeBalanceProviding
        let executor: DemeterMutationExtrinsicExecuting
    }

    private let expectedWalletId: MetaAccountId
    private let chainId: ChainModel.Id
    private let callBuilder: DemeterMutationCallBuilding
    private let chainRegistry: ChainRegistryProtocol
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?
    private let mutationsEnabled: () -> Bool

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        callBuilder: DemeterMutationCallBuilding,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        keystore: KeystoreProtocol = Keychain(),
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value },
        mutationsEnabled: @escaping () -> Bool = {
            MultiChainFeaturePolicy.current.demeterMutationsEnabled
        }
    ) {
        expectedWalletId = wallet.metaId
        chainId = chain.chainId
        self.callBuilder = callBuilder
        self.chainRegistry = chainRegistry
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.mutationsEnabled = mutationsEnabled
    }

    func authorize(_ mutation: DemeterMutation) async throws -> DemeterAuthorizedSubmission {
        try validatePolicyAndWallet()
        let context = try makeFreshContext()

        // First pass catches stale review data. The second pass deliberately
        // repeats runtime metadata/storage, exact balances and fee estimation
        // after those asynchronous reads, and is the only pass returned for
        // submission.
        _ = try await authorizeRound(mutation, context: context)
        try validateCurrentContext(context)
        let authorized = try await authorizeRound(mutation, context: context)
        try validateCurrentContext(context)

        return DemeterAuthorizedSubmission(
            builder: authorized.builder,
            executor: context.executor,
            finalGuard: { [weak self] in
                guard let self else { throw DemeterSubmissionError.runtimeUnavailable }
                try self.validateCurrentContext(context)
            }
        )
    }

    private func authorizeRound(
        _ mutation: DemeterMutation,
        context: Context
    ) async throws -> (builder: ExtrinsicBuilderClosure, fee: BigUInt) {
        try validateCurrentContext(context)
        let snapshot = try await context.snapshotProvider.snapshot()
        let boundMutation = try DemeterMutationBoundaryValidator.bind(mutation, to: snapshot)
        let builder = try callBuilder.builder(
            for: boundMutation,
            capabilities: snapshot.capabilities
        )
        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let requiredFee = BigUInt(dispatchInfo.fee, radix: 10), requiredFee > .zero else {
            throw DemeterSubmissionError.runtimeUnavailable
        }
        let balances = await context.balanceProvider.balances(
            for: boundMutation.pool.identity
        )
        _ = try DemeterMutationBoundaryValidator.validate(
            mutation,
            snapshot: snapshot,
            balances: balances,
            requiredFee: requiredFee
        )
        try validateCurrentContext(context)
        return (builder, requiredFee)
    }

    private func makeFreshContext() throws -> Context {
        guard chainId == PolkamarktConstants.soraChainId,
              let wallet = selectedWallet(),
              wallet.metaId == expectedWalletId,
              let chain = chainRegistry.getChain(for: chainId),
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chainId),
              runtime.snapshot != nil,
              let connection = chainRegistry.getConnection(for: chainId),
              let snapshotProvider = DemeterRuntimeService(
                  wallet: wallet,
                  chain: chain,
                  chainRegistry: chainRegistry
              ) else {
            if selectedWallet()?.metaId != expectedWalletId {
                throw DemeterSubmissionError.selectedWalletChanged
            }
            throw DemeterSubmissionError.runtimeUnavailable
        }
        let account = try validateSigningAccount(wallet: wallet, chain: chain)
        let signer = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: account
        )
        let extrinsic = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtime,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        return Context(
            wallet: wallet,
            chain: chain,
            account: account,
            runtime: runtime,
            connection: connection,
            snapshotProvider: snapshotProvider,
            balanceProvider: DemeterAuthoritativeBalanceProvider(wallet: wallet, chain: chain),
            executor: DemeterMutationExtrinsicExecutor(service: extrinsic, signer: signer)
        )
    }

    private func validatePolicyAndWallet() throws {
        guard mutationsEnabled() else {
            throw PolkamarktServiceError.actionsPaused
        }
        guard selectedWallet()?.metaId == expectedWalletId else {
            throw DemeterSubmissionError.selectedWalletChanged
        }
    }

    private func validateCurrentContext(_ context: Context) throws {
        try validatePolicyAndWallet()
        guard let wallet = selectedWallet(),
              wallet.metaId == context.wallet.metaId,
              let chain = chainRegistry.getChain(for: chainId),
              chain == context.chain,
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chainId),
              runtime.snapshot != nil,
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              let connection = chainRegistry.getConnection(for: chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection) else {
            throw DemeterSubmissionError.runtimeUnavailable
        }
        _ = try validateSigningAccount(
            wallet: wallet,
            chain: chain,
            expected: context.account
        )
    }

    private func validateSigningAccount(
        wallet: MetaAccountModel,
        chain: ChainModel,
        expected: ChainAccountResponse? = nil
    ) throws -> ChainAccountResponse {
        guard let account = wallet.fetch(for: chain.accountRequest()),
              expected.map({ $0.accountId == account.accountId }) ?? true else {
            throw DemeterSubmissionError.signerUnavailable
        }
        let accountId = account.isChainAccount ? account.accountId : nil
        let keyTag = chain.keystoreTag(metaId: wallet.metaId, accountId: accountId)
        guard (try? keystore.checkKey(for: keyTag)) == true else {
            throw DemeterSubmissionError.signerUnavailable
        }
        return account
    }
}

final class DemeterMutationService {
    private let initialCapabilities: DemeterRuntimeCapabilities
    private let callBuilder: DemeterMutationCallBuilding
    private let submissionAuthorizer: DemeterMutationSubmissionAuthorizing
    private let initialExecutor: DemeterMutationExtrinsicExecuting
    private let mutationsEnabled: () -> Bool

    init?(wallet: MetaAccountModel, chain: ChainModel, capabilities: DemeterRuntimeCapabilities) {
        let registry = ChainRegistryFacade.sharedRegistry
        guard chain.chainId == PolkamarktConstants.soraChainId,
              let account = wallet.fetch(for: chain.accountRequest()),
              let runtimeService = registry.getRuntimeProvider(for: chain.chainId),
              let connection = registry.getConnection(for: chain.chainId) else { return nil }
        let accountId = account.isChainAccount ? account.accountId : nil
        let tag = chain.keystoreTag(metaId: wallet.metaId, accountId: accountId)
        guard (try? Keychain().checkKey(for: tag)) == true else { return nil }

        let signer = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: account
        )
        let extrinsic = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        let callBuilder = DemeterMutationCallBuilder()
        initialCapabilities = capabilities
        self.callBuilder = callBuilder
        initialExecutor = DemeterMutationExtrinsicExecutor(service: extrinsic, signer: signer)
        submissionAuthorizer = DemeterMutationSubmissionAuthorizer(
            wallet: wallet,
            chain: chain,
            callBuilder: callBuilder
        )
        mutationsEnabled = { MultiChainFeaturePolicy.current.demeterMutationsEnabled }
    }

    init(
        initialCapabilities: DemeterRuntimeCapabilities,
        callBuilder: DemeterMutationCallBuilding,
        submissionAuthorizer: DemeterMutationSubmissionAuthorizing,
        initialExecutor: DemeterMutationExtrinsicExecuting,
        mutationsEnabled: @escaping () -> Bool
    ) {
        self.initialCapabilities = initialCapabilities
        self.callBuilder = callBuilder
        self.submissionAuthorizer = submissionAuthorizer
        self.initialExecutor = initialExecutor
        self.mutationsEnabled = mutationsEnabled
    }

    func estimateFee(for mutation: DemeterMutation) async throws -> RuntimeDispatchInfo {
        let builder = try callBuilder.builder(
            for: mutation,
            capabilities: initialCapabilities
        )
        return try await initialExecutor.estimateFee(builder)
    }

    func submit(_ mutation: DemeterMutation) async throws -> String {
        guard mutationsEnabled() else {
            throw PolkamarktServiceError.actionsPaused
        }
        let authorized = try await submissionAuthorizer.authorize(mutation)
        guard mutationsEnabled() else {
            throw PolkamarktServiceError.actionsPaused
        }
        // This synchronous guard is intentionally adjacent to submit. It
        // catches a wallet/key/runtime replacement or kill-switch update that
        // occurs after the final asynchronous storage/balance/fee pass.
        try authorized.finalGuard()
        return try await authorized.executor.submit(authorized.builder)
    }
}

enum DemeterFormatting {
    static func asset(for id: String, in chain: ChainModel) -> AssetModel? {
        chain.assets.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    static func symbol(for id: String, in chain: ChainModel) -> String {
        asset(for: id, in: chain)?.symbol ?? abbreviated(id)
    }

    static func precision(for id: String, in chain: ChainModel) -> UInt16 {
        asset(for: id, in: chain)?.precision ?? DemeterConstants.fixedPrecision
    }

    static func natural(_ planks: String, assetId: String, chain: ChainModel) -> Decimal? {
        guard let value = BigUInt(planks, radix: 10) else { return nil }
        return Decimal.fromSubstrateAmount(value, precision: Int16(precision(for: assetId, in: chain)))
    }

    static func naturalString(_ planks: String, assetId: String, chain: ChainModel) -> String {
        natural(planks, assetId: assetId, chain: chain).map {
            NSDecimalNumber(decimal: $0).stringValue
        } ?? planks
    }

    static func tvl(pool: DemeterPool, wallet: MetaAccountModel, chain: ChainModel) -> Decimal? {
        guard let amount = natural(pool.totalTokensInPool, assetId: pool.identity.poolAssetId, chain: chain),
              let price = asset(for: pool.identity.poolAssetId, in: chain)?
              .getPrice(for: wallet.selectedCurrency)?.price,
              let priceDecimal = Decimal(string: price) else { return nil }
        return amount * priceDecimal
    }

    static func apr(
        pool: DemeterPool,
        token: DemeterRewardToken?,
        wallet: MetaAccountModel,
        chain: ChainModel
    ) -> Decimal? {
        guard let token else { return nil }
        guard let totalMultiplier = BigUInt(
            pool.identity.isFarm ? token.farmsTotalMultiplier : token.stakingTotalMultiplier,
            radix: 10
        ), totalMultiplier > .zero,
        let poolMultiplier = BigUInt(pool.multiplier, radix: 10),
        let tokenPerBlock = BigUInt(token.tokenPerBlock, radix: 10),
        let allocation = BigUInt(
            pool.identity.isFarm ? token.farmsAllocation : token.stakingAllocation,
            radix: 10
        ) else { return nil }
        let divisor = BigUInt(10).power(Int(DemeterConstants.fixedPrecision)) * totalMultiplier
        let emission = tokenPerBlock * allocation * poolMultiplier / divisor
        guard let annual = Decimal.fromSubstrateAmount(
            emission,
            precision: Int16(precision(for: pool.identity.rewardAssetId, in: chain))
        ),
            let tvl = tvl(pool: pool, wallet: wallet, chain: chain), tvl > .zero,
            let rewardPrice = asset(for: pool.identity.rewardAssetId, in: chain)?
            .getPrice(for: wallet.selectedCurrency)?.price,
            let rewardPriceDecimal = Decimal(string: rewardPrice) else { return nil }
        return annual * DemeterConstants.blocksPerYear * rewardPriceDecimal / tvl * 100
    }

    private static func abbreviated(_ id: String) -> String {
        guard id.count > 12 else { return id }
        return "\(id.prefix(6))…\(id.suffix(4))"
    }
}

final class DemeterFarmingViewController: UIViewController {
    private enum Section: Int, CaseIterable { case positions, pools }

    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let service: DemeterRuntimeService?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activity = UIActivityIndicatorView(style: .medium)
    private var snapshot: DemeterSnapshot?

    init(wallet: MetaAccountModel, chain: ChainModel) {
        self.wallet = wallet
        self.chain = chain
        service = DemeterRuntimeService(wallet: wallet, chain: chain)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Demeter Farming"
        view.backgroundColor = R.color.colorBlack19()
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DemeterPool")
        let header = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 54))
        header.text = "  SORA Demeter pools · network fees paid in XOR"
        header.textColor = R.color.colorLightGray()
        header.font = .systemFont(ofSize: 13, weight: .medium)
        tableView.tableHeaderView = header
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activity)
        reload()
    }

    @objc private func reload() {
        guard let service else {
            presentMessage(
                title: "Demeter unavailable",
                message: "Connect to SORA Mainnet to discover Demeter farms."
            )
            return
        }
        activity.startAnimating()
        Task { [weak self] in
            guard let self else { return }
            do {
                let value = try await service.snapshot()
                await MainActor.run {
                    self.snapshot = value
                    self.activity.stopAnimating()
                    self.tableView.refreshControl?.endRefreshing()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.activity.stopAnimating()
                    self.tableView.refreshControl?.endRefreshing()
                    self.presentMessage(title: "Demeter unavailable", message: error.localizedDescription)
                }
            }
        }
    }

    private func activePositions() -> [DemeterAccountPosition] {
        snapshot?.positions.filter(\.isActive) ?? []
    }

    private func visiblePools() -> [DemeterPool] {
        guard let snapshot else { return [] }
        let identitiesWithPositions = Set(snapshot.positions.filter(\.isActive).map(\.identity))
        return snapshot.pools.filter { !$0.isRemoved || identitiesWithPositions.contains($0.identity) }.sorted {
            let lhsPosition = identitiesWithPositions.contains($0.identity)
            let rhsPosition = identitiesWithPositions.contains($1.identity)
            if lhsPosition != rhsPosition { return lhsPosition && !rhsPosition }
            let lhsApr = DemeterFormatting.apr(
                pool: $0,
                token: snapshot.rewardTokens[$0.identity.rewardAssetId.lowercased()],
                wallet: wallet,
                chain: chain
            ) ?? .zero
            let rhsApr = DemeterFormatting.apr(
                pool: $1,
                token: snapshot.rewardTokens[$1.identity.rewardAssetId.lowercased()],
                wallet: wallet,
                chain: chain
            ) ?? .zero
            return lhsApr > rhsApr
        }
    }

    private func open(pool: DemeterPool) {
        guard let snapshot else { return }
        let position = snapshot.positions.first { $0.identity == pool.identity }
        let controller = DemeterPoolDetailViewController(
            wallet: wallet,
            chain: chain,
            pool: pool,
            token: snapshot.rewardTokens[pool.identity.rewardAssetId.lowercased()],
            position: position,
            capabilities: snapshot.capabilities,
            onMutation: { [weak self] in self?.reload() }
        )
        controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension DemeterFarmingViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int { Section.allCases.count }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .positions ? "Your positions" : "Farms and staking"
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .positions: return max(activePositions().count, 1)
        case .pools: return max(visiblePools().count, 1)
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DemeterPool", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = R.color.colorWhite() ?? .white
        config.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        cell.backgroundColor = R.color.colorWhite8()
        cell.accessoryType = .none
        cell.selectionStyle = .none

        switch Section(rawValue: indexPath.section) {
        case .positions:
            guard let position = activePositions()[safe: indexPath.row],
                  let pool = snapshot?.pools.first(where: { $0.identity == position.identity }) else {
                config.text = "No active Demeter positions"
                config.secondaryText = wallet.fetch(for: chain.accountRequest()) == nil
                    ? "Add a SORA account to see positions and sign actions."
                    : "Positive deposits and unclaimed rewards appear here."
                break
            }
            let poolSymbol = DemeterFormatting.symbol(for: position.identity.poolAssetId, in: chain)
            let rewardSymbol = DemeterFormatting.symbol(for: position.identity.rewardAssetId, in: chain)
            config.text = "\(pool.identity.isFarm ? "Farm" : "Stake") \(poolSymbol)"
            config.secondaryText = "Deposited \(DemeterFormatting.naturalString(position.pooledTokens, assetId: position.identity.poolAssetId, chain: chain)) · Rewards \(DemeterFormatting.naturalString(position.rewards, assetId: position.identity.rewardAssetId, chain: chain)) \(rewardSymbol)"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .pools:
            guard let pool = visiblePools()[safe: indexPath.row] else {
                config.text = snapshot?.capabilities.unavailableReason ?? "No Demeter pools"
                config.secondaryText = "Closed pools remain visible when this wallet has a position."
                break
            }
            let poolSymbol = DemeterFormatting.symbol(for: pool.identity.poolAssetId, in: chain)
            let rewardSymbol = DemeterFormatting.symbol(for: pool.identity.rewardAssetId, in: chain)
            let token = snapshot?.rewardTokens[pool.identity.rewardAssetId.lowercased()]
            let apr = DemeterFormatting.apr(pool: pool, token: token, wallet: wallet, chain: chain)
            let tvl = DemeterFormatting.tvl(pool: pool, wallet: wallet, chain: chain)
            config.text = "\(pool.identity.isFarm ? "Farm" : "Stake") \(poolSymbol) → \(rewardSymbol)"
            config.secondaryText = "APR \(apr.map { "\(NSDecimalNumber(decimal: $0).rounding(accordingToBehavior: nil))%" } ?? "Price unavailable") · TVL \(tvl.map { "$\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "\(DemeterFormatting.naturalString(pool.totalTokensInPool, assetId: pool.identity.poolAssetId, chain: chain)) \(poolSymbol)")"
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .none:
            break
        }
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let pool: DemeterPool?
        if Section(rawValue: indexPath.section) == .positions,
           let position = activePositions()[safe: indexPath.row] {
            pool = snapshot?.pools.first { $0.identity == position.identity }
        } else {
            pool = visiblePools()[safe: indexPath.row]
        }
        if let pool { open(pool: pool) }
    }
}

final class DemeterPoolDetailViewController: UITableViewController {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let pool: DemeterPool
    private let token: DemeterRewardToken?
    private let position: DemeterAccountPosition?
    private let capabilities: DemeterRuntimeCapabilities
    private let onMutation: () -> Void

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        pool: DemeterPool,
        token: DemeterRewardToken?,
        position: DemeterAccountPosition?,
        capabilities: DemeterRuntimeCapabilities,
        onMutation: @escaping () -> Void
    ) {
        self.wallet = wallet
        self.chain = chain
        self.pool = pool
        self.token = token
        self.position = position
        self.capabilities = capabilities
        self.onMutation = onMutation
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let symbol = DemeterFormatting.symbol(for: pool.identity.poolAssetId, in: chain)
        title = "\(pool.identity.isFarm ? "Farm" : "Stake") \(symbol)"
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DemeterDetail")
    }

    override func numberOfSections(in _: UITableView) -> Int { 3 }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Pool", "Your position", "Actions"][safe: section]
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 4 : (section == 1 ? 2 : 3)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DemeterDetail", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.color = R.color.colorWhite() ?? .white
        config.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        cell.backgroundColor = R.color.colorWhite8()
        cell.selectionStyle = .none
        cell.accessoryType = .none
        let poolSymbol = DemeterFormatting.symbol(for: pool.identity.poolAssetId, in: chain)
        let rewardSymbol = DemeterFormatting.symbol(for: pool.identity.rewardAssetId, in: chain)

        if indexPath.section == 0 {
            let apr = DemeterFormatting.apr(pool: pool, token: token, wallet: wallet, chain: chain)
            let tvl = DemeterFormatting.tvl(pool: pool, wallet: wallet, chain: chain)
            let rows = [
                ("Protocol", "SORA · Demeter Farming · XOR network fees"),
                ("Rewards", rewardSymbol),
                ("APR", apr.map { "\(NSDecimalNumber(decimal: $0).stringValue)%" } ?? "Price unavailable"),
                ("TVL", tvl.map { "$\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "\(DemeterFormatting.naturalString(pool.totalTokensInPool, assetId: pool.identity.poolAssetId, chain: chain)) \(poolSymbol) · fiat price unavailable")
            ]
            config.text = rows[indexPath.row].0
            config.secondaryText = rows[indexPath.row].1
        } else if indexPath.section == 1 {
            config.text = indexPath.row == 0 ? "Deposited" : "Claimable rewards"
            let raw = indexPath.row == 0 ? (position?.pooledTokens ?? "0") : (position?.rewards ?? "0")
            let assetId = indexPath.row == 0 ? pool.identity.poolAssetId : pool.identity.rewardAssetId
            let symbol = indexPath.row == 0 ? poolSymbol : rewardSymbol
            config.secondaryText = "\(DemeterFormatting.naturalString(raw, assetId: assetId, chain: chain)) \(symbol)"
        } else {
            config.text = ["Deposit", "Withdraw", "Claim rewards"][indexPath.row]
            if indexPath.row == 0, pool.isRemoved {
                config.secondaryText = "This pool is closed to new deposits."
            } else {
                config.secondaryText = capabilities.canMutate
                    ? "Review amount and estimated XOR fee"
                    : capabilities.unavailableReason
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }
        if indexPath.row == 2 {
            transact(.claim(pool: pool))
        } else {
            requestAmount(deposit: indexPath.row == 0)
        }
    }

    private func requestAmount(deposit: Bool) {
        guard !deposit || !pool.isRemoved else {
            presentMessage(title: "Pool closed", message: "Withdrawals and claims remain available.")
            return
        }
        let symbol = DemeterFormatting.symbol(for: pool.identity.poolAssetId, in: chain)
        let alert = UIAlertController(
            title: deposit ? "Deposit \(symbol)" : "Withdraw \(symbol)",
            message: "Enter a positive amount. The SORA network fee is paid in XOR.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Review", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let input = alert?.textFields?.first?.text,
                  let value = Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")),
                  value > .zero,
                  let amount = value.toSubstrateAmount(
                      precision: Int16(DemeterFormatting.precision(for: self.pool.identity.poolAssetId, in: self.chain))
                  ) else {
                self?.presentMessage(title: "Invalid amount", message: "Enter a positive decimal amount.")
                return
            }
            self.transact(
                deposit
                    ? .deposit(pool: self.pool, amount: amount.description)
                    : .withdraw(pool: self.pool, amount: amount.description)
            )
        })
        present(alert, animated: true)
    }

    private func transact(_ mutation: DemeterMutation) {
        guard MultiChainFeaturePolicy.current.demeterMutationsEnabled else {
            presentMessage(
                title: "Actions paused",
                message: "Demeter actions are temporarily disabled by the remote safety switch."
            )
            return
        }
        guard let service = DemeterMutationService(wallet: wallet, chain: chain, capabilities: capabilities) else {
            presentMessage(
                title: "Cannot sign",
                message: "Add a signable SORA account. This wallet may be watch-only or use unsupported external signing."
            )
            return
        }
        Task {
            do {
                let fee = try await service.estimateFee(for: mutation)
                await MainActor.run { self.confirm(mutation, service: service, fee: fee.fee) }
            } catch {
                await MainActor.run {
                    self.presentMessage(title: "Action unavailable", message: error.localizedDescription)
                }
            }
        }
    }

    private func confirm(_ mutation: DemeterMutation, service: DemeterMutationService, fee: String) {
        let alert = UIAlertController(
            title: "Confirm on SORA",
            message: "Estimated network fee: \(DemeterFormatting.naturalString(fee, assetId: PolkamarktConstants.feeAssetId, chain: chain)) XOR",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            Task {
                do {
                    let hash = try await service.submit(mutation)
                    await MainActor.run {
                        self?.onMutation()
                        self?.presentMessage(title: "Submitted", message: "SORA extrinsic \(hash)")
                    }
                } catch {
                    await MainActor.run {
                        self?.presentMessage(title: "Transaction failed", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
