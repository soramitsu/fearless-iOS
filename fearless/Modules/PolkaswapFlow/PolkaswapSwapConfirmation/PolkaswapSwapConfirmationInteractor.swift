import BigInt
import RobinHood
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import UIKit

enum PolkaswapSubmissionError: LocalizedError, Equatable {
    case actionsPaused
    case disclaimerRequired
    case selectedWalletChanged
    case soraRuntimeUnavailable
    case accountUnavailable
    case watchOnly
    case unregisteredAsset
    case invalidAmount
    case balanceUnavailable
    case insufficientInputBalance
    case insufficientFeeBalance

    var errorDescription: String? {
        switch self {
        case .actionsPaused:
            return "Swaps are temporarily disabled by the remote safety switch."
        case .disclaimerRequired:
            return "Read and accept the current Polkaswap disclaimer before swapping."
        case .selectedWalletChanged:
            return "The selected wallet changed. Review the Polkaswap quote again."
        case .soraRuntimeUnavailable:
            return "The production SORA runtime is unavailable. Refresh the network and try again."
        case .accountUnavailable:
            return "Add a SORA account to use Polkaswap."
        case .watchOnly:
            return "This wallet cannot sign SORA transactions."
        case .unregisteredAsset:
            return "The exact input or output asset is no longer registered on SORA. Refresh assets and request a new quote."
        case .invalidAmount:
            return "The swap amount or limit is invalid. Request a new quote."
        case .balanceUnavailable:
            return "The current SORA balances are unavailable. Refresh before submitting."
        case .insufficientInputBalance:
            return "The current spendable input balance is insufficient for this swap."
        case .insufficientFeeBalance:
            return "The current spendable XOR balance is insufficient for the swap and network fee."
        }
    }
}

struct PolkaswapSwapResolvedAmounts: Equatable {
    let desired: BigUInt
    let slip: BigUInt
    let requiredInput: BigUInt

    static func resolve(_ params: PolkaswapPreviewParams) throws -> PolkaswapSwapResolvedAmounts {
        guard params.fromAmount > .zero,
              params.toAmount > .zero,
              params.minMaxValue > .zero else {
            throw PolkaswapSubmissionError.invalidAmount
        }

        let fromPrecision = Int16(params.swapFromChainAsset.asset.precision)
        let toPrecision = Int16(params.swapToChainAsset.asset.precision)

        switch params.swapVariant {
        case .desiredInput:
            guard let desired = params.fromAmount.toSubstrateAmount(precision: fromPrecision),
                  let slip = params.minMaxValue.toSubstrateAmount(precision: toPrecision),
                  desired > .zero,
                  slip > .zero else {
                throw PolkaswapSubmissionError.invalidAmount
            }
            return PolkaswapSwapResolvedAmounts(
                desired: desired,
                slip: slip,
                requiredInput: desired
            )
        case .desiredOutput:
            guard let desired = params.toAmount.toSubstrateAmount(precision: toPrecision),
                  let slip = params.minMaxValue.toSubstrateAmount(precision: fromPrecision),
                  desired > .zero,
                  slip > .zero else {
                throw PolkaswapSubmissionError.invalidAmount
            }
            return PolkaswapSwapResolvedAmounts(
                desired: desired,
                slip: slip,
                requiredInput: slip
            )
        }
    }
}

enum PolkaswapFeeCoverage {
    static func isSufficient(
        inputIsXor: Bool,
        outputIsXor: Bool,
        swapVariant: SwapVariant,
        amounts: PolkaswapSwapResolvedAmounts,
        xorBalance: BigUInt,
        fee: BigUInt
    ) -> Bool {
        if inputIsXor {
            return xorBalance >= amounts.requiredInput + fee
        }

        if outputIsXor {
            let boundedOutput: BigUInt
            switch swapVariant {
            case .desiredInput:
                boundedOutput = amounts.slip
            case .desiredOutput:
                boundedOutput = amounts.desired
            }

            return xorBalance + boundedOutput >= fee
        }

        return xorBalance >= fee
    }
}

enum PolkaswapRegisteredAssetResolver {
    static let xorCurrencyId = "0x0200000000000000000000000000000000000000000000000000000000000000"

    static func exactAsset(
        _ requested: ChainAsset,
        in currentChain: ChainModel
    ) throws -> ChainAsset {
        guard requested.chain.chainId == currentChain.chainId,
              let currencyId = requested.asset.currencyId,
              !currencyId.isEmpty else {
            throw PolkaswapSubmissionError.unregisteredAsset
        }

        let matches = currentChain.chainAssets.filter { $0.assetKey == requested.assetKey }
        guard matches.count == 1,
              let match = matches.first,
              match.asset.currencyId == currencyId,
              match.asset.precision == requested.asset.precision,
              match.asset.type == requested.asset.type else {
            throw PolkaswapSubmissionError.unregisteredAsset
        }
        return match
    }

    static func exactXorAsset(
        _ requested: ChainAsset,
        in currentChain: ChainModel
    ) throws -> ChainAsset {
        let matches = currentChain.chainAssets.filter {
            $0.asset.currencyId == xorCurrencyId
        }
        guard matches.count == 1,
              let match = matches.first,
              requested.assetKey == match.assetKey,
              requested.asset.currencyId == xorCurrencyId,
              requested.asset.precision == match.asset.precision,
              requested.asset.type == match.asset.type else {
            throw PolkaswapSubmissionError.unregisteredAsset
        }
        return match
    }
}

protocol PolkaswapSwapCallBuilding {
    func builder(for params: PolkaswapPreviewParams) throws -> ExtrinsicBuilderClosure
}

struct PolkaswapSwapCallBuilder: PolkaswapSwapCallBuilding {
    let callFactory: SubstrateCallFactoryProtocol

    func builder(for params: PolkaswapPreviewParams) throws -> ExtrinsicBuilderClosure {
        guard let fromAssetId = params.swapFromChainAsset.asset.currencyId,
              !fromAssetId.isEmpty,
              let toAssetId = params.swapToChainAsset.asset.currencyId,
              !toAssetId.isEmpty,
              fromAssetId != toAssetId else {
            throw PolkaswapSubmissionError.unregisteredAsset
        }

        let amounts = try PolkaswapSwapResolvedAmounts.resolve(params)
        let swapAmount = SwapAmount(
            type: params.swapVariant,
            desired: amounts.desired,
            slip: amounts.slip
        )
        let swapCall = callFactory.swap(
            dexId: "\(params.polkaswapDexForRoute.code)",
            from: fromAssetId,
            to: toAssetId,
            amountCall: [params.swapVariant: swapAmount],
            type: params.market.code,
            filter: params.market.filterMode.rawValue
        )

        return { builder in
            try builder.adding(call: swapCall)
        }
    }
}

protocol PolkaswapExtrinsicExecuting {
    func estimateFee(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo
    func submit(_ builder: @escaping ExtrinsicBuilderClosure) async throws -> String
}

final class PolkaswapExtrinsicExecutor: PolkaswapExtrinsicExecuting {
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

struct PolkaswapAuthorizedSubmission {
    let builder: ExtrinsicBuilderClosure
    let executor: PolkaswapExtrinsicExecuting
    let finalGuard: () throws -> Void
}

protocol PolkaswapSubmissionAuthorizing {
    func authorize(params: PolkaswapPreviewParams) async throws -> PolkaswapAuthorizedSubmission
}

/// Re-resolves every mutable dependency at confirmation time. The quote screen
/// is intentionally not trusted for runtime, signing, registry or balance state.
final class PolkaswapSubmissionAuthorizer: PolkaswapSubmissionAuthorizing {
    private let chainRegistry: ChainRegistryProtocol
    private let settings: SettingsManagerProtocol
    private let keystore: KeystoreProtocol
    private let accountInfoFetching: AccountInfoFetchingProtocol
    private let selectedWallet: () -> MetaAccountModel?

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        settings: SettingsManagerProtocol = SettingsManager.shared,
        keystore: KeystoreProtocol = Keychain(),
        accountInfoFetching: AccountInfoFetchingProtocol? = nil,
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value }
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.keystore = keystore
        self.selectedWallet = selectedWallet

        if let accountInfoFetching {
            self.accountInfoFetching = accountInfoFetching
        } else {
            let repository = SubstrateRepositoryFactory(
                storageFacade: UserDataStorageFacade.shared
            ).createAccountInfoStorageItemRepository()
            self.accountInfoFetching = AccountInfoFetching(
                accountInfoRepository: repository,
                chainRegistry: chainRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        }
    }

    func authorize(params: PolkaswapPreviewParams) async throws -> PolkaswapAuthorizedSubmission {
        let expectedWalletId = params.wallet.metaId
        try validatePolicyAndWallet(expectedWalletId: expectedWalletId)
        let context = try makeFreshContext(params: params, expectedWalletId: expectedWalletId)

        // Repeat the exact asset, amount, balance and fee boundary after the
        // first asynchronous pass. Only the second runtime-bound builder can
        // escape this authorizer for submission.
        _ = try await authorizeRound(params: params, context: context)
        try validateCurrentContext(context, params: params, expectedWalletId: expectedWalletId)
        let builder = try await authorizeRound(params: params, context: context)
        try validateCurrentContext(context, params: params, expectedWalletId: expectedWalletId)

        return PolkaswapAuthorizedSubmission(
            builder: builder,
            executor: context.executor,
            finalGuard: { [weak self] in
                guard let self else { throw PolkaswapSubmissionError.soraRuntimeUnavailable }
                try self.validateCurrentContext(
                    context,
                    params: params,
                    expectedWalletId: expectedWalletId
                )
            }
        )
    }

    private struct Context {
        let wallet: MetaAccountModel
        let chain: ChainModel
        let account: ChainAccountResponse
        let runtime: RuntimeProviderProtocol
        let connection: JSONRPCEngine
        let runtimeSpecVersion: UInt32
        let executor: PolkaswapExtrinsicExecuting
    }

    private func makeFreshContext(
        params: PolkaswapPreviewParams,
        expectedWalletId: MetaAccountId
    ) throws -> Context {
        guard params.soraChinAsset.chain.chainId == Chain.soraMain.genesisHash,
              params.swapFromChainAsset.chain.chainId == Chain.soraMain.genesisHash,
              params.swapToChainAsset.chain.chainId == Chain.soraMain.genesisHash,
              let wallet = selectedWallet(),
              wallet.metaId == expectedWalletId,
              let chain = chainRegistry.getChain(for: Chain.soraMain.genesisHash),
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chain.chainId),
              let snapshot = runtime.snapshot,
              let connection = chainRegistry.getConnection(for: chain.chainId) else {
            if selectedWallet()?.metaId != expectedWalletId {
                throw PolkaswapSubmissionError.selectedWalletChanged
            }
            throw PolkaswapSubmissionError.soraRuntimeUnavailable
        }
        let account = try validateSigningAccount(wallet: wallet, chain: chain)
        let signer = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: account
        )
        let service = ExtrinsicService(
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
            runtimeSpecVersion: snapshot.specVersion,
            executor: PolkaswapExtrinsicExecutor(service: service, signer: signer)
        )
    }

    private func authorizeRound(
        params: PolkaswapPreviewParams,
        context: Context
    ) async throws -> ExtrinsicBuilderClosure {
        try validateCurrentContext(
            context,
            params: params,
            expectedWalletId: params.wallet.metaId
        )
        let fromAsset = try PolkaswapRegisteredAssetResolver.exactAsset(
            params.swapFromChainAsset,
            in: context.chain
        )
        let toAsset = try PolkaswapRegisteredAssetResolver.exactAsset(
            params.swapToChainAsset,
            in: context.chain
        )
        let xorAsset = try PolkaswapRegisteredAssetResolver.exactXorAsset(
            params.soraChinAsset,
            in: context.chain
        )
        let amounts = try PolkaswapSwapResolvedAmounts.resolve(params)
        let builder = try PolkaswapSwapCallBuilder(
            callFactory: SubstrateCallFactoryDefault(runtimeService: context.runtime)
        ).builder(for: params)

        let dispatchInfo = try await context.executor.estimateFee(builder)
        guard let fee = BigUInt(dispatchInfo.fee, radix: 10) else {
            throw PolkaswapSubmissionError.soraRuntimeUnavailable
        }
        let balanceAssets = fromAsset.assetKey == xorAsset.assetKey
            ? [fromAsset]
            : [fromAsset, xorAsset]
        let accountInfos: [ChainAsset: AccountInfo?]
        do {
            accountInfos = try await accountInfoFetching.fetch(
                for: balanceAssets,
                wallet: context.wallet
            )
        } catch {
            throw PolkaswapSubmissionError.balanceUnavailable
        }

        guard let inputBalance = spendableBalance(for: fromAsset, in: accountInfos),
              let xorBalance = spendableBalance(for: xorAsset, in: accountInfos) else {
            throw PolkaswapSubmissionError.balanceUnavailable
        }
        guard inputBalance >= amounts.requiredInput else {
            throw PolkaswapSubmissionError.insufficientInputBalance
        }

        guard PolkaswapFeeCoverage.isSufficient(
            inputIsXor: fromAsset.assetKey == xorAsset.assetKey,
            outputIsXor: toAsset.assetKey == xorAsset.assetKey,
            swapVariant: params.swapVariant,
            amounts: amounts,
            xorBalance: xorBalance,
            fee: fee
        ) else {
            throw PolkaswapSubmissionError.insufficientFeeBalance
        }
        try validateCurrentContext(
            context,
            params: params,
            expectedWalletId: params.wallet.metaId
        )
        return builder
    }

    private func validatePolicies() throws {
        guard MultiChainFeaturePolicy.current.polkaswapMutationsEnabled else {
            throw PolkaswapSubmissionError.actionsPaused
        }
        guard PolkaswapDisclaimerPolicy.isAccepted(in: settings) else {
            throw PolkaswapSubmissionError.disclaimerRequired
        }
    }

    private func validatePolicyAndWallet(expectedWalletId: MetaAccountId) throws {
        try validatePolicies()
        guard selectedWallet()?.metaId == expectedWalletId else {
            throw PolkaswapSubmissionError.selectedWalletChanged
        }
    }

    private func validateCurrentContext(
        _ context: Context,
        params: PolkaswapPreviewParams,
        expectedWalletId: MetaAccountId
    ) throws {
        try validatePolicyAndWallet(expectedWalletId: expectedWalletId)
        guard let wallet = selectedWallet(),
              wallet.metaId == context.wallet.metaId,
              let chain = chainRegistry.getChain(for: context.chain.chainId),
              chain == context.chain,
              !chain.disabled,
              !chain.isTestnet,
              let runtime = chainRegistry.getRuntimeProvider(for: chain.chainId),
              ObjectIdentifier(runtime) == ObjectIdentifier(context.runtime),
              runtime.snapshot?.specVersion == context.runtimeSpecVersion,
              let connection = chainRegistry.getConnection(for: chain.chainId),
              ObjectIdentifier(connection) == ObjectIdentifier(context.connection) else {
            throw PolkaswapSubmissionError.soraRuntimeUnavailable
        }
        _ = try PolkaswapRegisteredAssetResolver.exactAsset(params.swapFromChainAsset, in: chain)
        _ = try PolkaswapRegisteredAssetResolver.exactAsset(params.swapToChainAsset, in: chain)
        _ = try PolkaswapRegisteredAssetResolver.exactXorAsset(params.soraChinAsset, in: chain)
        _ = try validateSigningAccount(wallet: wallet, chain: chain, expected: context.account)
    }

    private func validateSigningAccount(
        wallet: MetaAccountModel,
        chain: ChainModel,
        expected: ChainAccountResponse? = nil
    ) throws -> ChainAccountResponse {
        guard let account = wallet.fetch(for: chain.accountRequest()),
              expected.map({
                  $0.chainId == account.chainId &&
                      $0.walletId == account.walletId &&
                      $0.isChainAccount == account.isChainAccount &&
                      $0.accountId == account.accountId &&
                      $0.publicKey == account.publicKey &&
                      $0.cryptoType == account.cryptoType
              }) ?? true else {
            throw PolkaswapSubmissionError.accountUnavailable
        }

        let chainAccountId = account.isChainAccount ? account.accountId : nil
        let tag = chain.keystoreTag(metaId: wallet.metaId, accountId: chainAccountId)
        guard (try? keystore.checkKey(for: tag)) == true else {
            throw PolkaswapSubmissionError.watchOnly
        }
        return account
    }

    private func spendableBalance(
        for asset: ChainAsset,
        in accountInfos: [ChainAsset: AccountInfo?]
    ) -> BigUInt? {
        guard let entry = accountInfos.first(where: { $0.key.assetKey == asset.assetKey }) else {
            return nil
        }

        return entry.value?.data.sendAvailable ?? .zero
    }
}

final class PolkaswapSwapConfirmationInteractor: RuntimeConstantFetching {
    private weak var output: PolkaswapSwapConfirmationInteractorOutput?

    private var params: PolkaswapPreviewParams
    private let submissionAuthorizer: PolkaswapSubmissionAuthorizing
    private let mutationsEnabled: () -> Bool
    private let disclaimerAccepted: () -> Bool

    init(params: PolkaswapPreviewParams) {
        self.params = params
        submissionAuthorizer = PolkaswapSubmissionAuthorizer()
        mutationsEnabled = { MultiChainFeaturePolicy.current.polkaswapMutationsEnabled }
        disclaimerAccepted = { PolkaswapDisclaimerPolicy.isAccepted() }
    }

    init(
        params: PolkaswapPreviewParams,
        submissionAuthorizer: PolkaswapSubmissionAuthorizing,
        mutationsEnabled: @escaping () -> Bool,
        disclaimerAccepted: @escaping () -> Bool
    ) {
        self.params = params
        self.submissionAuthorizer = submissionAuthorizer
        self.mutationsEnabled = mutationsEnabled
        self.disclaimerAccepted = disclaimerAccepted
    }
}

// MARK: - PolkaswapSwapConfirmationInteractorInput

extension PolkaswapSwapConfirmationInteractor: PolkaswapSwapConfirmationInteractorInput {
    func setup(with output: PolkaswapSwapConfirmationInteractorOutput) {
        self.output = output
    }

    func update(params: PolkaswapPreviewParams) {
        self.params = params
    }

    func submit() {
        let paramsSnapshot = params
        Task { [weak self] in
            guard let self else { return }

            do {
                let authorized = try await submissionAuthorizer.authorize(params: paramsSnapshot)

                // These two guards deliberately live in the interactor as well
                // as the production authorizer so a UI/presenter bypass cannot
                // submit after a last-moment policy change.
                guard mutationsEnabled() else {
                    throw PolkaswapSubmissionError.actionsPaused
                }
                guard disclaimerAccepted() else {
                    throw PolkaswapSubmissionError.disclaimerRequired
                }
                // The synchronous identity check is deliberately adjacent to
                // invoking the fresh executor retained by authorization.
                try authorized.finalGuard()
                let hash = try await authorized.executor.submit(authorized.builder)
                await MainActor.run { [weak self] in
                    self?.output?.didReceive(extrinsicResult: .success(hash))
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.output?.didReceive(extrinsicResult: .failure(error))
                }
            }
        }
    }
}
