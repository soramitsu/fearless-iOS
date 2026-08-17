import Foundation
import SoraKeystore
import SSFChainRegistry
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils
import SSFXCM
import BigInt

protocol LiquidityPoolsModelFactory {
    func buildReserves(
        pool: LiquidityPair,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal?
    func buildReserves(
        accountPool: AccountPool,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal?
}

final class LiquidityPoolsModelFactoryDefault: LiquidityPoolsModelFactory {
    func buildReserves(
        pool: LiquidityPair,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal? {
        buildReserves(
            chain: chain,
            baseAssetId: pool.baseAssetId,
            targetAssetId: pool.targetAssetId,
            reservesInfo: reservesInfo,
            baseAssetPrice: baseAssetPrice,
            targetAssetPrice: targetAssetPrice
        )
    }

    func buildReserves(
        accountPool: AccountPool,
        chain: ChainModel,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal? {
        buildReserves(
            chain: chain,
            baseAssetId: accountPool.baseAssetId,
            targetAssetId: accountPool.targetAssetId,
            reservesInfo: reservesInfo,
            baseAssetPrice: baseAssetPrice,
            targetAssetPrice: targetAssetPrice
        )
    }

    private func buildReserves(
        chain: ChainModel,
        baseAssetId: String,
        targetAssetId: String,
        reservesInfo: PolkaswapPoolReservesInfo?,
        baseAssetPrice: PriceData?,
        targetAssetPrice: PriceData?
    ) -> Decimal? {
        let baseAsset = chain.assets.first(where: { $0.currencyId == baseAssetId })
        let targetAsset = chain.assets.first(where: { $0.currencyId == targetAssetId })

        guard let baseAsset, let targetAsset else {
            return nil
        }

        let poolReservesValue = (reservesInfo?.reserves.reserves).flatMap {
            Decimal.fromSubstrateAmount($0, precision: Int16(baseAsset.precision))
        }
        let baseAssetPriceValue = (baseAssetPrice?.price).flatMap { Decimal(string: $0) }
        let poolFeeValue = (reservesInfo?.reserves.fee).flatMap {
            Decimal.fromSubstrateAmount($0, precision: Int16(targetAsset.precision))
        }
        let targetAssetPriceValue = (targetAssetPrice?.price).flatMap { Decimal(string: $0) }

        return poolReservesValue.flatMap { poolReserves in
            guard let baseAssetPriceValue, let poolFeeValue, let targetAssetPriceValue else {
                return nil
            }

            return (poolReserves * baseAssetPriceValue) + (poolFeeValue * targetAssetPriceValue)
        }
    }
}

public extension AssetModel {
    /// Resolves only a price whose provider and fiat currency identities were
    /// preserved by the live or migrated price cache. The legacy scalar
    /// `price` has no currency provenance and must never be relabelled here.
    func getPrice(for currency: Currency) -> PriceData? {
        guard let priceId else {
            return nil
        }

        return ExactAssetPriceCache.shared.price(
            priceId: priceId,
            currencyId: currency.id
        )
    }
}

public extension SSFPools.LiquidityPair {
    var dexId: String { "0" }
}

// Convenience mapping used by presenters when navigating from account pools
public extension SSFPools.AccountPool {
    var liquidityPair: SSFPools.LiquidityPair {
        SSFPools.LiquidityPair(
            pairId: poolId,
            chainId: chainId,
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            reserves: nil,
            apy: apy,
            reservesId: reservesId
        )
    }
}

/// App-facing adapter around the production SORA pool storage implementation.
///
/// The previous implementation returned immediately-finished streams and nil
/// values, which made the promoted DeFi entry look functional while never
/// exposing a pool.  This adapter deliberately keeps the existing presenter
/// API stable while all values originate from runtime-backed storage or the
/// Polkaswap APY endpoint.
final class PolkaswapLiquidityPoolService {
    private let upstream: SSFPolkaswap.PolkaswapLiquidityPoolService
    private let poolStorage: PoolXykStorage
    private let chain: ChainModel

    init(
        upstream: SSFPolkaswap.PolkaswapLiquidityPoolService,
        poolStorage: PoolXykStorage,
        chain: ChainModel
    ) {
        self.upstream = upstream
        self.poolStorage = poolStorage
        self.chain = chain
    }

    func subscribeLiquidityPool(
        assetIdPair: AssetIdPair
    ) async throws -> AsyncStream<CachedStorageResponse<LiquidityPair?>> {
        let pools = try await upstream.fetchAvailablePools()
        let matches = pools.filter {
            $0.baseAssetId.caseInsensitiveCompare(assetIdPair.baseAssetId.code) == .orderedSame &&
                $0.targetAssetId.caseInsensitiveCompare(assetIdPair.targetAssetId.code) == .orderedSame
        }
        let value = matches.count == 1 ? matches[0] : nil
        return oneShot(CachedStorageResponse(value: value, type: .remote))
    }

    func subscribeUserPools(
        accountId: Data
    ) async throws -> AsyncStream<CachedStorageResponse<[AccountPool]>> {
        let pools = try await upstream.fetchUserPools(accountId: accountId)
        return oneShot(CachedStorageResponse(value: pools, type: .remote))
    }

    func subscribeAvailablePools() async throws -> AsyncStream<CachedStorageResponse<[LiquidityPair]>> {
        let pools = try await upstream.fetchAvailablePools()
        return oneShot(CachedStorageResponse(value: pools, type: .remote))
    }

    func subscribePoolReserves(
        assetIdPair: AssetIdPair
    ) async throws -> AsyncStream<CachedStorageResponse<PolkaswapPoolReservesInfo>> {
        let values = try await poolStorage.reserves(pairs: [assetIdPair], chain: chain)
        let matches = values.filter { $0.poolId == assetIdPair.poolId }
        guard matches.count == 1, let value = matches.first else {
            throw PoolXykStorageError.reservesNotFound(pairs: [assetIdPair])
        }
        return oneShot(CachedStorageResponse(value: value, type: .remote))
    }

    func subscribePoolsReserves(
        pools: [LiquidityPair]
    ) async throws -> AsyncStream<CachedStorageResponse<[PolkaswapPoolReservesInfo]>> {
        let pairs = pools.map {
            AssetIdPair(baseAssetIdCode: $0.baseAssetId, targetAssetIdCode: $0.targetAssetId)
        }
        let values = try await poolStorage.reserves(pairs: pairs, chain: chain)
        return oneShot(CachedStorageResponse(value: values, type: .remote))
    }

    func subscribePoolsAPY(
        poolIds: [String]
    ) async throws -> AsyncStream<[CachedStorageResponse<PoolApyInfo?>]> {
        let requested = Set(poolIds)
        let values = try await upstream.fetchPoolsAPY().filter { requested.contains($0.poolId) }
        let response = values.map { CachedStorageResponse<PoolApyInfo?>(value: $0, type: .remote) }
        return oneShot(response)
    }

    func fetchUserPool(assetIdPair: AssetIdPair, accountId: Data) async throws -> AccountPool? {
        let pools = try await upstream.fetchUserPools(accountId: accountId).filter {
            $0.baseAssetId.caseInsensitiveCompare(assetIdPair.baseAssetId.code) == .orderedSame &&
                $0.targetAssetId.caseInsensitiveCompare(assetIdPair.targetAssetId.code) == .orderedSame
        }
        guard pools.count <= 1 else { throw PoolsOperationServiceError.unexpectedError }
        return pools.first
    }

    func fetchTotalIssuance(reservesId: Data) async throws -> BigUInt? {
        try await poolStorage.totalIssuance(chain: chain)[reservesId]
    }

    private func oneShot<T>(_ value: T) -> AsyncStream<T> {
        AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }
}

enum PolkaswapLiquidityPoolServiceAssembly {
    static func buildService(
        for chain: ChainModel,
        chainRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol
    ) -> PolkaswapLiquidityPoolService {
        let performer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )
        return PolkaswapLiquidityPoolService(
            upstream: SSFPolkaswap.PolkaswapLiquidityPoolServiceAssembly.buildService(
                for: chain,
                chainRegistry: chainRegistry
            ),
            poolStorage: PoolXykStorageDefaultL(storageRequestPerformer: performer),
            chain: chain
        )
    }

    static func buildOperationService(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol
    ) throws -> PoolsOperationService {
        guard let service = ReviewedPolkaswapPoolsOperationService(
            chain: chain,
            wallet: wallet,
            chainRegistry: chainRegistry
        ) else {
            throw PoolsOperationServiceError.unexpectedError
        }
        return service
    }
}

struct ReviewedPoolRuntimeModule: Equatable {
    let name: String
    let calls: Set<String>

    private func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "")
    }

    func resolvedCall(_ requested: String) -> String? {
        calls.first { normalized($0) == normalized(requested) }
    }
}

struct ReviewedPoolRuntimeCapabilities: Equatable {
    let tradingPair: ReviewedPoolRuntimeModule?
    let poolXYK: ReviewedPoolRuntimeModule?

    var canDepositExisting: Bool {
        poolXYK?.resolvedCall("depositLiquidity") != nil
    }

    var canCreateAndDeposit: Bool {
        tradingPair?.resolvedCall("register") != nil &&
            poolXYK?.resolvedCall("initializePool") != nil &&
            canDepositExisting
    }

    var canWithdraw: Bool {
        poolXYK?.resolvedCall("withdrawLiquidity") != nil
    }
}

struct ReviewedPoolRegisterCall: Codable {
    let dexId: String
    let baseAssetId: SoraAssetId
    let targetAssetId: SoraAssetId
}

struct ReviewedPoolInitializeCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
}

struct ReviewedPoolDepositCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
    let desiredA: String
    let desiredB: String
    let minA: String
    let minB: String

    enum CodingKeys: String, CodingKey {
        case dexId
        case assetA = "inputAssetA"
        case assetB = "inputAssetB"
        case desiredA = "inputADesired"
        case desiredB = "inputBDesired"
        case minA = "inputAMin"
        case minB = "inputBMin"
    }
}

struct ReviewedPoolWithdrawCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
    let assetDesired: String
    let minA: String
    let minB: String

    enum CodingKeys: String, CodingKey {
        case dexId
        case assetA = "outputAssetA"
        case assetB = "outputAssetB"
        case assetDesired = "markerAssetDesired"
        case minA = "outputAMin"
        case minB = "outputBMin"
    }
}

enum ReviewedPolkaswapPoolSubmissionError: LocalizedError, Equatable {
    case actionsPaused
    case disclaimerRequired
    case selectedWalletChanged
    case runtimeUnavailable
    case signerUnavailable
    case runtimeCallUnavailable
    case invalidPair
    case invalidAmount
    case poolUnavailable
    case positionUnavailable
    case insufficientPosition
    case balanceUnavailable
    case insufficientAsset
    case insufficientFee

    var errorDescription: String? {
        switch self {
        case .actionsPaused:
            return "Liquidity actions are temporarily disabled by the remote safety switch."
        case .disclaimerRequired:
            return "Read and accept the current Polkaswap disclaimer before changing SORA liquidity."
        case .selectedWalletChanged:
            return "The selected wallet changed. Review the liquidity action again."
        case .runtimeUnavailable:
            return "The authoritative SORA runtime is unavailable."
        case .signerUnavailable:
            return "A local SORA signing key is required. Watch-only and unsupported external signing cannot submit this action."
        case .runtimeCallUnavailable:
            return "The current SORA runtime does not expose the required reviewed liquidity call."
        case .invalidPair:
            return "The exact SORA liquidity pair is not registered in this wallet or runtime."
        case .invalidAmount:
            return "Enter positive liquidity amounts and a valid slippage limit."
        case .poolUnavailable:
            return "The exact SORA liquidity pool is unavailable."
        case .positionUnavailable:
            return "The authoritative account liquidity position is unavailable."
        case .insufficientPosition:
            return "The current account position is smaller than this withdrawal."
        case .balanceUnavailable:
            return "The exact asset or XOR balance is unavailable. Refresh SORA before submitting."
        case .insufficientAsset:
            return "The current spendable asset balance is insufficient for this deposit."
        case .insufficientFee:
            return "The current spendable XOR balance is insufficient for the exact network fee."
        }
    }
}

private final class ReviewedPoolExtrinsicExecutor {
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

/// Exact, fail-closed mutation boundary for SORA PoolXYK.
///
/// Every submission is rebuilt from current metadata and storage twice. The
/// second round owns the builder that is submitted, and a synchronous guard is
/// run immediately before signing so a changed wallet, key, runtime, connection,
/// disclaimer, or kill switch cannot reuse an earlier review.
final class ReviewedPolkaswapPoolsOperationService: PoolsOperationService {
    private struct Context {
        let wallet: MetaAccountModel
        let chain: ChainModel
        let account: ChainAccountResponse
        let runtime: RuntimeProviderProtocol
        let connection: JSONRPCEngine
        let dataService: PolkaswapLiquidityPoolService
        let executor: ReviewedPoolExtrinsicExecutor
    }

    private struct BoundOperation {
        let operation: PoolOperation
        let poolExists: Bool
        let capabilities: ReviewedPoolRuntimeCapabilities
    }

    private struct AuthorizedSubmission {
        let builder: ExtrinsicBuilderClosure
        let executor: ReviewedPoolExtrinsicExecutor
        let finalGuard: () throws -> Void
    }

    private let expectedWalletId: MetaAccountId
    private let chainId: ChainModel.Id
    private let appRegistry: ChainRegistryProtocol
    private let sharedRegistry: SSFChainRegistry.ChainRegistryProtocol
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?
    private let mutationsEnabled: () -> Bool
    private let disclaimerAccepted: () -> Bool

    init?(
        chain: ChainModel,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol,
        keystore: KeystoreProtocol = Keychain(),
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value },
        mutationsEnabled: @escaping () -> Bool = {
            MultiChainFeaturePolicy.current.polkaswapMutationsEnabled
        },
        disclaimerAccepted: @escaping () -> Bool = { PolkaswapDisclaimerPolicy.isAccepted() }
    ) {
        guard chain.chainId == PolkamarktConstants.soraChainId, !chain.isTestnet else { return nil }
        expectedWalletId = wallet.metaId
        chainId = chain.chainId
        appRegistry = chainRegistry
        sharedRegistry = chainRegistry
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.mutationsEnabled = mutationsEnabled
        self.disclaimerAccepted = disclaimerAccepted
    }

    func estimateFee(liquidityOperation: PoolOperation) async throws -> BigUInt {
        let context = try makeFreshContext(requirePolicy: false)
        let bound = try await bind(liquidityOperation, context: context)
        let builder = try makeBuilder(for: bound)
        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let fee = BigUInt(dispatchInfo.fee, radix: 10), fee > .zero else {
            throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
        }
        return fee
    }

    func submit(liquidityOperation: PoolOperation) async throws -> String {
        let authorized = try await authorize(liquidityOperation)
        try authorized.finalGuard()
        return try await authorized.executor.submit(authorized.builder)
    }

    private func authorize(_ operation: PoolOperation) async throws -> AuthorizedSubmission {
        try validatePolicyAndWallet()
        let context = try makeFreshContext(requirePolicy: true)

        _ = try await authorizeRound(operation, context: context)
        try validateCurrentContext(context)
        let builder = try await authorizeRound(operation, context: context)
        try validateCurrentContext(context)

        return AuthorizedSubmission(
            builder: builder,
            executor: context.executor,
            finalGuard: { [weak self] in
                guard let self else {
                    throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
                }
                try self.validateCurrentContext(context)
            }
        )
    }

    private func authorizeRound(
        _ operation: PoolOperation,
        context: Context
    ) async throws -> ExtrinsicBuilderClosure {
        try validateCurrentContext(context)
        let bound = try await bind(operation, context: context)
        let builder = try makeBuilder(for: bound)
        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let fee = BigUInt(dispatchInfo.fee, radix: 10), fee > .zero else {
            throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
        }
        try await validateBalances(for: bound.operation, fee: fee, context: context)
        try validateCurrentContext(context)
        return builder
    }

    private func makeFreshContext(requirePolicy: Bool) throws -> Context {
        if requirePolicy { try validatePolicyAndWallet() }
        guard let wallet = selectedWallet(), wallet.metaId == expectedWalletId,
              let chain = appRegistry.getChain(for: chainId),
              chain.chainId == PolkamarktConstants.soraChainId,
              !chain.disabled,
              !chain.isTestnet,
              let runtime = appRegistry.getRuntimeProvider(for: chainId),
              runtime.snapshot != nil,
              let connection = appRegistry.getConnection(for: chainId) else {
            if selectedWallet()?.metaId != expectedWalletId {
                throw ReviewedPolkaswapPoolSubmissionError.selectedWalletChanged
            }
            throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
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
        let performer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: sharedRegistry
        )
        let dataService = PolkaswapLiquidityPoolService(
            upstream: SSFPolkaswap.PolkaswapLiquidityPoolServiceAssembly.buildService(
                for: chain,
                chainRegistry: sharedRegistry
            ),
            poolStorage: PoolXykStorageDefaultL(storageRequestPerformer: performer),
            chain: chain
        )
        return Context(
            wallet: wallet,
            chain: chain,
            account: account,
            runtime: runtime,
            connection: connection,
            dataService: dataService,
            executor: ReviewedPoolExtrinsicExecutor(service: extrinsic, signer: signer)
        )
    }

    private func runtimeCapabilities(
        runtime: RuntimeProviderProtocol
    ) async throws -> ReviewedPoolRuntimeCapabilities {
        let factory = try await runtime.fetchCoderFactory()

        func module(_ requested: String) -> ReviewedPoolRuntimeModule? {
            guard let metadataModule = factory.metadata.modules.first(where: {
                normalized($0.name) == normalized(requested)
            }) else { return nil }
            let calls = (try? metadataModule.calls(using: factory.metadata.schemaResolver)) ?? []
            return ReviewedPoolRuntimeModule(name: metadataModule.name, calls: Set(calls.map(\.name)))
        }

        return ReviewedPoolRuntimeCapabilities(
            tradingPair: module("TradingPair"),
            poolXYK: module("PoolXYK")
        )
    }

    private func bind(
        _ operation: PoolOperation,
        context: Context
    ) async throws -> BoundOperation {
        let capabilities = try await runtimeCapabilities(runtime: context.runtime)

        switch operation {
        case let .substrateSupplyLiquidity(model):
            try validatePair(
                dexId: model.dexId,
                baseAsset: model.baseAsset,
                targetAsset: model.targetAsset,
                chain: context.chain
            )
            guard model.baseAssetAmount > .zero,
                  model.targetAssetAmount > .zero,
                  model.slippage >= .zero,
                  model.slippage < 100,
                  model.baseAssetAmount.toSubstrateAmount(precision: model.baseAsset.precision) != nil,
                  model.targetAssetAmount.toSubstrateAmount(precision: model.targetAsset.precision) != nil,
                  model.amountMinA.toSubstrateAmount(precision: model.baseAsset.precision) != nil,
                  model.amountMinB.toSubstrateAmount(precision: model.targetAsset.precision) != nil else {
                throw ReviewedPolkaswapPoolSubmissionError.invalidAmount
            }
            let pools = try await fetchExactAvailablePools(
                baseAssetId: model.baseAsset.id,
                targetAssetId: model.targetAsset.id,
                service: context.dataService
            )
            guard pools.count <= 1 else { throw ReviewedPolkaswapPoolSubmissionError.invalidPair }
            let exists = pools.count == 1
            guard exists ? capabilities.canDepositExisting : capabilities.canCreateAndDeposit else {
                throw ReviewedPolkaswapPoolSubmissionError.runtimeCallUnavailable
            }
            if exists {
                _ = try await fetchExactReserves(
                    baseAssetId: model.baseAsset.id,
                    targetAssetId: model.targetAsset.id,
                    service: context.dataService
                )
            }
            return BoundOperation(
                operation: .substrateSupplyLiquidity(model),
                poolExists: exists,
                capabilities: capabilities
            )

        case let .substrateRemoveLiquidity(model):
            try validatePair(
                dexId: model.dexId,
                baseAsset: model.baseAsset,
                targetAsset: model.targetAsset,
                chain: context.chain
            )
            guard model.baseAssetAmount > .zero,
                  model.targetAssetAmount > .zero,
                  model.slippage >= .zero,
                  model.slippage < 100,
                  capabilities.canWithdraw else {
                throw ReviewedPolkaswapPoolSubmissionError.invalidAmount
            }
            let pools = try await fetchExactAvailablePools(
                baseAssetId: model.baseAsset.id,
                targetAssetId: model.targetAsset.id,
                service: context.dataService
            )
            guard pools.count == 1 else { throw ReviewedPolkaswapPoolSubmissionError.poolUnavailable }
            let pair = AssetIdPair(
                baseAssetIdCode: model.baseAsset.id,
                targetAssetIdCode: model.targetAsset.id
            )
            guard let accountPool = try await context.dataService.fetchUserPool(
                assetIdPair: pair,
                accountId: context.account.accountId
            ),
                let currentBase = accountPool.baseAssetPooled,
                let currentTarget = accountPool.targetAssetPooled else {
                throw ReviewedPolkaswapPoolSubmissionError.positionUnavailable
            }
            guard currentBase >= model.baseAssetAmount,
                  currentTarget >= model.targetAssetAmount else {
                throw ReviewedPolkaswapPoolSubmissionError.insufficientPosition
            }
            let reserves = try await fetchExactReserves(
                baseAssetId: model.baseAsset.id,
                targetAssetId: model.targetAsset.id,
                service: context.dataService
            )
            guard let reservesIdHex = accountPool.reservesId,
                  let reservesId = try? Data(hexStringSSF: reservesIdHex),
                  let issuance = try await context.dataService.fetchTotalIssuance(reservesId: reservesId),
                  issuance > .zero,
                  let currentBaseReserves = Decimal.fromSubstrateAmount(
                      reserves.reserves.reserves,
                      precision: model.baseAsset.precision
                  ),
                  let currentIssuance = Decimal.fromSubstrateAmount(
                      issuance,
                      precision: model.baseAsset.precision
                  ),
                  currentBaseReserves > .zero,
                  currentIssuance > .zero else {
                throw ReviewedPolkaswapPoolSubmissionError.positionUnavailable
            }
            let currentModel = RemoveLiquidityInfo(
                dexId: model.dexId,
                baseAsset: model.baseAsset,
                targetAsset: model.targetAsset,
                baseAssetAmount: model.baseAssetAmount,
                targetAssetAmount: model.targetAssetAmount,
                baseAssetReserves: currentBaseReserves,
                totalIssuances: currentIssuance,
                slippage: model.slippage
            )
            guard currentModel.assetDesired > .zero,
                  currentModel.assetDesired.toSubstrateAmount(precision: model.baseAsset.precision) != nil,
                  currentModel.amountMinA.toSubstrateAmount(precision: model.baseAsset.precision) != nil,
                  currentModel.amountMinB.toSubstrateAmount(precision: model.targetAsset.precision) != nil else {
                throw ReviewedPolkaswapPoolSubmissionError.invalidAmount
            }
            return BoundOperation(
                operation: .substrateRemoveLiquidity(currentModel),
                poolExists: true,
                capabilities: capabilities
            )
        }
    }

    private func makeBuilder(for bound: BoundOperation) throws -> ExtrinsicBuilderClosure {
        switch bound.operation {
        case let .substrateSupplyLiquidity(model):
            guard let poolModule = bound.capabilities.poolXYK,
                  let depositName = poolModule.resolvedCall("depositLiquidity"),
                  let desiredA = model.baseAssetAmount.toSubstrateAmount(precision: model.baseAsset.precision),
                  let desiredB = model.targetAssetAmount.toSubstrateAmount(precision: model.targetAsset.precision),
                  let minA = model.amountMinA.toSubstrateAmount(precision: model.baseAsset.precision),
                  let minB = model.amountMinB.toSubstrateAmount(precision: model.targetAsset.precision) else {
                throw ReviewedPolkaswapPoolSubmissionError.runtimeCallUnavailable
            }
            let deposit = RuntimeCall(
                moduleName: poolModule.name,
                callName: depositName,
                args: ReviewedPoolDepositCall(
                    dexId: model.dexId,
                    assetA: SoraAssetId(wrappedValue: model.baseAsset.id),
                    assetB: SoraAssetId(wrappedValue: model.targetAsset.id),
                    desiredA: desiredA.description,
                    desiredB: desiredB.description,
                    minA: minA.description,
                    minB: minB.description
                )
            )
            if bound.poolExists {
                return { try $0.with(shouldUseAtomicBatch: true).adding(call: deposit) }
            }
            guard let pairModule = bound.capabilities.tradingPair,
                  let registerName = pairModule.resolvedCall("register"),
                  let initializeName = poolModule.resolvedCall("initializePool") else {
                throw ReviewedPolkaswapPoolSubmissionError.runtimeCallUnavailable
            }
            let register = RuntimeCall(
                moduleName: pairModule.name,
                callName: registerName,
                args: ReviewedPoolRegisterCall(
                    dexId: model.dexId,
                    baseAssetId: SoraAssetId(wrappedValue: model.baseAsset.id),
                    targetAssetId: SoraAssetId(wrappedValue: model.targetAsset.id)
                )
            )
            let initialize = RuntimeCall(
                moduleName: poolModule.name,
                callName: initializeName,
                args: ReviewedPoolInitializeCall(
                    dexId: model.dexId,
                    assetA: SoraAssetId(wrappedValue: model.baseAsset.id),
                    assetB: SoraAssetId(wrappedValue: model.targetAsset.id)
                )
            )
            return {
                try $0.with(shouldUseAtomicBatch: true)
                    .adding(call: register)
                    .adding(call: initialize)
                    .adding(call: deposit)
            }

        case let .substrateRemoveLiquidity(model):
            guard let poolModule = bound.capabilities.poolXYK,
                  let withdrawName = poolModule.resolvedCall("withdrawLiquidity"),
                  let assetDesired = model.assetDesired.toSubstrateAmount(precision: model.baseAsset.precision),
                  let minA = model.amountMinA.toSubstrateAmount(precision: model.baseAsset.precision),
                  let minB = model.amountMinB.toSubstrateAmount(precision: model.targetAsset.precision) else {
                throw ReviewedPolkaswapPoolSubmissionError.runtimeCallUnavailable
            }
            let withdraw = RuntimeCall(
                moduleName: poolModule.name,
                callName: withdrawName,
                args: ReviewedPoolWithdrawCall(
                    dexId: model.dexId,
                    assetA: SoraAssetId(wrappedValue: model.baseAsset.id),
                    assetB: SoraAssetId(wrappedValue: model.targetAsset.id),
                    assetDesired: assetDesired.description,
                    minA: minA.description,
                    minB: minB.description
                )
            )
            return { try $0.adding(call: withdraw) }
        }
    }

    private func validateBalances(
        for operation: PoolOperation,
        fee: BigUInt,
        context: Context
    ) async throws {
        let performer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: sharedRegistry
        )
        let accountService = AccountInfoRemoteServiceDefault(storagePerformer: performer)
        guard let accountInfos = try? await accountService.fetchAccountInfos(
            for: context.chain,
            wallet: context.wallet
        ) else {
            throw ReviewedPolkaswapPoolSubmissionError.balanceUnavailable
        }
        let feeAssets = exactChainAssets(
            id: PolkamarktConstants.feeAssetId,
            chain: context.chain
        )
        guard feeAssets.count == 1,
              let feeInfo: AccountInfo = accountInfos[feeAssets[0].chainAssetId] ?? nil else {
            throw ReviewedPolkaswapPoolSubmissionError.balanceUnavailable
        }
        let feeSpendable = feeInfo.data.sendAvailable

        switch operation {
        case let .substrateSupplyLiquidity(model):
            let baseAssets = exactChainAssets(id: model.baseAsset.id, chain: context.chain)
            let targetAssets = exactChainAssets(id: model.targetAsset.id, chain: context.chain)
            guard baseAssets.count == 1,
                  targetAssets.count == 1,
                  let baseInfo: AccountInfo = accountInfos[baseAssets[0].chainAssetId] ?? nil,
                  let targetInfo: AccountInfo = accountInfos[targetAssets[0].chainAssetId] ?? nil,
                  let baseAmount = model.baseAssetAmount.toSubstrateAmount(
                      precision: model.baseAsset.precision
                  ),
                  let targetAmount = model.targetAssetAmount.toSubstrateAmount(
                      precision: model.targetAsset.precision
                  ) else {
                throw ReviewedPolkaswapPoolSubmissionError.balanceUnavailable
            }
            let baseIsFee = normalized(model.baseAsset.id) == normalized(PolkamarktConstants.feeAssetId)
            let targetIsFee = normalized(model.targetAsset.id) == normalized(PolkamarktConstants.feeAssetId)
            guard baseInfo.data.sendAvailable >= baseAmount + (baseIsFee ? fee : .zero),
                  targetInfo.data.sendAvailable >= targetAmount + (targetIsFee ? fee : .zero) else {
                throw ReviewedPolkaswapPoolSubmissionError.insufficientAsset
            }
            if !baseIsFee, !targetIsFee, feeSpendable < fee {
                throw ReviewedPolkaswapPoolSubmissionError.insufficientFee
            }
        case .substrateRemoveLiquidity:
            guard feeSpendable >= fee else {
                throw ReviewedPolkaswapPoolSubmissionError.insufficientFee
            }
        }
    }

    private func validatePair(
        dexId: String,
        baseAsset: PooledAssetInfo,
        targetAsset: PooledAssetInfo,
        chain: ChainModel
    ) throws {
        let baseMatches = exactChainAssets(id: baseAsset.id, chain: chain)
        let targetMatches = exactChainAssets(id: targetAsset.id, chain: chain)
        guard dexId == "0",
              normalized(baseAsset.id) != normalized(targetAsset.id),
              baseMatches.count == 1,
              targetMatches.count == 1,
              baseMatches[0].asset.precision == UInt16(baseAsset.precision),
              targetMatches[0].asset.precision == UInt16(targetAsset.precision) else {
            throw ReviewedPolkaswapPoolSubmissionError.invalidPair
        }
    }

    private func fetchExactAvailablePools(
        baseAssetId: String,
        targetAssetId: String,
        service: PolkaswapLiquidityPoolService
    ) async throws -> [LiquidityPair] {
        let stream = try await service.subscribeAvailablePools()
        for await response in stream {
            return (response.value ?? []).filter {
                normalized($0.baseAssetId) == normalized(baseAssetId) &&
                    normalized($0.targetAssetId) == normalized(targetAssetId)
            }
        }
        throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
    }

    private func fetchExactReserves(
        baseAssetId: String,
        targetAssetId: String,
        service: PolkaswapLiquidityPoolService
    ) async throws -> PolkaswapPoolReservesInfo {
        let pair = AssetIdPair(
            baseAssetIdCode: baseAssetId,
            targetAssetIdCode: targetAssetId
        )
        let stream = try await service.subscribePoolReserves(assetIdPair: pair)
        for await response in stream {
            guard let reserves = response.value,
                  reserves.poolId == pair.poolId else {
                throw ReviewedPolkaswapPoolSubmissionError.poolUnavailable
            }
            return reserves
        }
        throw ReviewedPolkaswapPoolSubmissionError.poolUnavailable
    }

    private func exactChainAssets(id: String, chain: ChainModel) -> [ChainAsset] {
        chain.chainAssets.filter {
            guard let currencyId = $0.asset.currencyId else { return false }
            return normalized(currencyId) == normalized(id)
        }
    }

    private func validatePolicyAndWallet() throws {
        guard mutationsEnabled() else { throw ReviewedPolkaswapPoolSubmissionError.actionsPaused }
        guard disclaimerAccepted() else { throw ReviewedPolkaswapPoolSubmissionError.disclaimerRequired }
        guard selectedWallet()?.metaId == expectedWalletId else {
            throw ReviewedPolkaswapPoolSubmissionError.selectedWalletChanged
        }
    }

    private func validateCurrentContext(_ context: Context) throws {
        try validatePolicyAndWallet()
        guard let wallet = selectedWallet(), wallet.metaId == context.wallet.metaId,
              let chain = appRegistry.getChain(for: chainId),
              chain == context.chain,
              !chain.disabled,
              !chain.isTestnet,
              let runtime = appRegistry.getRuntimeProvider(for: chainId),
              runtime.snapshot != nil,
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              let connection = appRegistry.getConnection(for: chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection) else {
            throw ReviewedPolkaswapPoolSubmissionError.runtimeUnavailable
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
            throw ReviewedPolkaswapPoolSubmissionError.signerUnavailable
        }
        let accountId = account.isChainAccount ? account.accountId : nil
        let tag = chain.keystoreTag(metaId: wallet.metaId, accountId: accountId)
        guard (try? keystore.checkKey(for: tag)) == true else {
            throw ReviewedPolkaswapPoolSubmissionError.signerUnavailable
        }
        return account
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "_", with: "")
    }
}

// (removed) Network compatibility shims are defined centrally under Common/Compatibility
