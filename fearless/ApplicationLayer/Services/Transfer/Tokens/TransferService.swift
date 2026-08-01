import Foundation
import SSFModels
import SSFExtrinsicKit
import SSFUtils
import BigInt
import TonSwift

protocol TransferFeeEstimationListener: AnyObject {
    func didReceiveFee(fee: BigUInt)
    func didReceiveFeeError(feeError: Error)
}

protocol TonTransferFeePresentationListener: TransferFeeEstimationListener {
    func didReceiveTonFee(fee: BigUInt, presentationID: String)
}

enum TransferServiceError: Error {
    case cannotEstimateFee(reason: String)
    case transferFailed(reason: String)
    case tonProductionSendDisabled
    case tonPriorTransferConfirmed(identity: TonTransferIntentIdentity, messageHashHex: String)
    case tonBroadcastOutcomeUnknown(messageHashHex: String)
    case unexpected
}

struct Transfer {
    let chainAsset: ChainAsset
    let amount: BigUInt
    let receiver: String
    let tip: BigUInt?
    let appId: BigUInt?
}

protocol TransferServiceProtocol {
    func estimateFee(for transfer: Transfer) async throws -> BigUInt
    func submit(transfer: Transfer) async throws -> String
    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener)
    func unsubscribe()
    func confirmFeePresentation(id: String, fee: BigUInt) async -> Bool
    func acknowledgeSubmittedTransfer(hash: String, transfer: Transfer) async -> Bool
    func acknowledgeRecoveredTransfer(
        hash: String,
        identity: TonTransferIntentIdentity
    ) async -> Bool

    func estimateFee(for transfer: XorlessTransfer) async throws -> BigUInt
    func submit(transfer: XorlessTransfer) async throws -> String
}

extension TransferServiceProtocol {
    func estimateFee(for _: XorlessTransfer) async throws -> BigUInt { .zero }
    func submit(transfer _: XorlessTransfer) async throws -> String { "" }
    func confirmFeePresentation(id _: String, fee _: BigUInt) async -> Bool { true }
    func acknowledgeSubmittedTransfer(hash _: String, transfer _: Transfer) async -> Bool { true }
    func acknowledgeRecoveredTransfer(
        hash _: String,
        identity _: TonTransferIntentIdentity
    ) async -> Bool { true }
}

final class BitcoinTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let planner: BitcoinSendPlanner
    private let sendService: BitcoinSendService
    private let mnemonicProvider: BitcoinMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        client: BitcoinIndexerClientProtocol = BitcoinIndexerClient(),
        mnemonicProvider: BitcoinMnemonicProviding = KeychainBitcoinMnemonicProvider()
    ) {
        self.wallet = wallet
        self.chain = chain
        planner = BitcoinSendPlanner(client: client)
        sendService = BitcoinSendService(client: client)
        self.mnemonicProvider = mnemonicProvider
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        let context = try resolveContext(failure: TransferServiceError.cannotEstimateFee(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let plan = try await planner.plan(
            amountSats: amountSats,
            sources: [BitcoinUtxoSource(address: context.sourceAddress)],
            recipientAddress: transfer.receiver,
            changeAddress: context.sourceAddress,
            network: context.network,
            baseURL: context.baseURL
        )

        return BigUInt(UInt64(plan.feeSats))
    }

    func submit(transfer: Transfer) async throws -> String {
        let context = try resolveContext(failure: TransferServiceError.transferFailed(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try BitcoinKeyDerivation.deriveAccount(
                mnemonic: mnemonic,
                network: bitcoinKeyDerivationNetwork(for: context.network)
            ).firstReceiveAddress
        } catch {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic root material is invalid")
        }

        guard derivedAddress.lowercased() == context.sourceAddress.lowercased() else {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic does not match selected wallet")
        }

        let result = try await sendService.send(
            BitcoinSendRequest(
                mnemonic: mnemonic,
                amountSats: amountSats,
                sources: [BitcoinUtxoSource(address: context.sourceAddress)],
                recipientAddress: transfer.receiver,
                changeAddress: context.sourceAddress,
                network: context.network,
                baseURL: context.baseURL
            )
        )

        return result.broadcastTxid
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        failure: (String) -> TransferServiceError
    ) throws -> BitcoinTransferContext {
        guard let network = bitcoinNetwork(for: chain) else {
            throw failure("Unsupported Bitcoin chain: \(chain.chainId)")
        }

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Bitcoin account address is unavailable for \(chain.chainId)")
        }

        let indexerNetwork = bitcoinIndexerNetwork(for: network)
        let normalizedSourceAddress: String
        do {
            normalizedSourceAddress = try BitcoinIndexerRoutes.normalizeAddress(
                sourceAddress,
                network: indexerNetwork
            )
        } catch {
            throw failure("Bitcoin source address is invalid")
        }

        return BitcoinTransferContext(
            sourceAddress: normalizedSourceAddress,
            network: indexerNetwork,
            baseURL: chain.externalApi?.history?.url.absoluteString
        )
    }

    private func resolveAmountSats(
        _ amount: BigUInt,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Bitcoin transfer amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let amountSats = Int64(amount.description)
        else {
            throw failure("Bitcoin transfer amount is too large")
        }

        return amountSats
    }

    private func bitcoinNetwork(for chain: ChainModel) -> UniversalWalletRegistry.BitcoinNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return UniversalWalletRegistry.bitcoinMainnet
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return UniversalWalletRegistry.bitcoinTestnet
        default:
            return nil
        }
    }

    private func bitcoinIndexerNetwork(
        for network: UniversalWalletRegistry.BitcoinNetwork
    ) -> BitcoinIndexerNetwork {
        network == UniversalWalletRegistry.bitcoinTestnet ? .testnet : .mainnet
    }

    private func bitcoinKeyDerivationNetwork(
        for network: BitcoinIndexerNetwork
    ) -> BitcoinKeyDerivation.Network {
        switch network {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
}

private final class TonTransferFeeQuoteStore: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var pendingIdentity: TonTransferIntentIdentity?
    private var quote: TonTransferFeeQuote?
    private var readyForSubmission = false

    func begin(identity: TonTransferIntentIdentity) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation = generation == UInt64.max ? 1 : generation + 1
        pendingIdentity = identity
        quote = nil
        readyForSubmission = false
        return generation
    }

    func commit(
        _ quote: TonTransferFeeQuote,
        identity: TonTransferIntentIdentity,
        generation expectedGeneration: UInt64,
        readyForSubmission: Bool
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration,
              pendingIdentity == identity,
              quote.identity == identity
        else {
            return false
        }
        self.quote = quote
        self.readyForSubmission = readyForSubmission
        return true
    }

    func fail(generation expectedGeneration: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration else { return }
        pendingIdentity = nil
        quote = nil
        readyForSubmission = false
    }

    func activate(presentationID: String, fee: BigUInt) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let quote,
              quote.quoteIDHex == presentationID,
              fee == BigUInt(quote.feeNanotons),
              pendingIdentity == quote.identity
        else {
            return false
        }
        readyForSubmission = true
        return true
    }

    func consume(identity: TonTransferIntentIdentity) -> TonTransferFeeQuote? {
        lock.lock()
        defer { lock.unlock() }
        guard pendingIdentity == identity,
              quote?.identity == identity,
              readyForSubmission
        else {
            return nil
        }
        let result = quote
        pendingIdentity = nil
        quote = nil
        readyForSubmission = false
        return result
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        generation = generation == UInt64.max ? 1 : generation + 1
        pendingIdentity = nil
        quote = nil
        readyForSubmission = false
    }
}

final class TonTransferService: TransferServiceProtocol {
    private struct PreparedFeePresentation {
        let fee: BigUInt
        let presentationID: String
    }

    private struct ResolvedTransfer {
        let publicKey: Data
        let senderAddress: String
        let recipientAddress: String
        let amountNanotons: String
        let bounce: Bool
    }

    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let sendService: TonSendService
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private let feeQuoteStore = TonTransferFeeQuoteStore()
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        remote: TonTransferRemoteProtocol,
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
        clock: @escaping @Sendable() -> UInt64 = { UInt64(Date().timeIntervalSince1970) }
    ) {
        self.wallet = wallet
        self.chain = chain
        self.mnemonicProvider = mnemonicProvider
        sendService = TonSendService(
            remote: remote,
            clock: clock
        )
    }

    #if DEBUG
        init(
            wallet: MetaAccountModel,
            chain: ChainModel,
            remote: TonTransferRemoteProtocol,
            mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
            pendingCoordinator: TonPendingIntentCoordinator,
            clock: @escaping @Sendable() -> UInt64 = { UInt64(Date().timeIntervalSince1970) }
        ) {
            self.wallet = wallet
            self.chain = chain
            self.mnemonicProvider = mnemonicProvider
            sendService = TonSendService(
                remote: remote,
                pendingCoordinator: pendingCoordinator,
                clock: clock
            )
        }
    #endif

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        // This compatibility API may calculate a fee, but it must never authorize a send.
        // Only the typed listener path exposes the opaque quote ID that the rendered UI can
        // acknowledge before submission.
        try await prepareFee(for: transfer, readyForSubmission: false).fee
    }

    private func prepareFee(
        for transfer: Transfer,
        readyForSubmission: Bool
    ) async throws -> PreparedFeePresentation {
        let resolved = try resolveTransfer(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        do {
            let estimateRequest = TonNativeEstimateRequest(
                publicKey: resolved.publicKey,
                senderAddress: resolved.senderAddress,
                recipientAddress: resolved.recipientAddress,
                amountNanotons: resolved.amountNanotons,
                bounce: resolved.bounce
            )
            let identity = try TonTransferIntentIdentity(request: estimateRequest)
            let generation = feeQuoteStore.begin(identity: identity)
            do {
                let quote = try await sendService.quote(estimateRequest)
                try Task.checkCancellation()
                guard feeQuoteStore.commit(
                    quote,
                    identity: identity,
                    generation: generation,
                    readyForSubmission: readyForSubmission
                ) else {
                    throw CancellationError()
                }
                // Close cancellation between the remote result and local publication. `fail`
                // below synchronously revokes this exact generation if cancellation won.
                try Task.checkCancellation()
                return PreparedFeePresentation(
                    fee: BigUInt(quote.feeNanotons),
                    presentationID: quote.quoteIDHex
                )
            } catch {
                feeQuoteStore.fail(generation: generation)
                throw error
            }
        } catch let error as TransferServiceError {
            throw error
        } catch {
            throw TransferServiceError.cannotEstimateFee(reason: "TON transfer validation or emulation failed")
        }
    }

    func submit(transfer: Transfer) async throws -> String {
        #if !DEBUG
            // Keep the integration boundary fail-closed before transfer resolution or
            // mnemonic/keychain access, even if same-module code bypasses normal DI.
            throw TransferServiceError.tonProductionSendDisabled
        #else
            let resolved = try resolveTransfer(
                for: transfer,
                failure: TransferServiceError.transferFailed(reason:)
            )

            let identity = try TonTransferIntentIdentity(
                request: TonNativeEstimateRequest(
                    publicKey: resolved.publicKey,
                    senderAddress: resolved.senderAddress,
                    recipientAddress: resolved.recipientAddress,
                    amountNanotons: resolved.amountNanotons,
                    bounce: resolved.bounce
                )
            )
            // Atomically consume the exact quote. A nil quote is still passed through so
            // TonSendService can recover an already-persisted same-intent BOC after restart;
            // a genuinely fresh unquoted send fails before signing or remote work.
            let feeQuote = feeQuoteStore.consume(identity: identity)

            do {
                return try await sendService.send(
                    TonNativeEstimateRequest(
                        publicKey: resolved.publicKey,
                        senderAddress: resolved.senderAddress,
                        recipientAddress: resolved.recipientAddress,
                        amountNanotons: resolved.amountNanotons,
                        bounce: resolved.bounce
                    ),
                    feeQuote: feeQuote,
                    signingCredentials: {
                        guard let mnemonic = try self.mnemonicProvider.mnemonic(
                            for: self.wallet,
                            chain: self.chain
                        ) else {
                            throw TonSendServiceError.invalidAccount
                        }
                        return TonSigningCredentials(mnemonic: mnemonic)
                    }
                ).messageHashHex
            } catch let error as TonSendServiceError {
                if case let .priorIntentConfirmed(identity, messageHashHex) = error {
                    throw TransferServiceError.tonPriorTransferConfirmed(
                        identity: identity,
                        messageHashHex: messageHashHex
                    )
                }
                if case let .broadcastOutcomeUnknown(messageHashHex) = error {
                    throw TransferServiceError.tonBroadcastOutcomeUnknown(
                        messageHashHex: messageHashHex
                    )
                }
                throw TransferServiceError.transferFailed(reason: "TON transfer validation, emulation, or broadcast failed")
            } catch {
                throw TransferServiceError.transferFailed(reason: "TON transfer validation, emulation, or broadcast failed")
            }
        #endif
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let presentation = try await self.prepareFee(
                    for: transfer,
                    readyForSubmission: false
                )
                guard !Task.isCancelled else {
                    return
                }
                if let listener = listener as? TonTransferFeePresentationListener {
                    listener.didReceiveTonFee(
                        fee: presentation.fee,
                        presentationID: presentation.presentationID
                    )
                } else {
                    listener?.didReceiveFee(fee: presentation.fee)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeQuoteStore.invalidate()
        feeTask?.cancel()
        feeTask = nil
    }

    func confirmFeePresentation(id: String, fee: BigUInt) async -> Bool {
        feeQuoteStore.activate(presentationID: id, fee: fee)
    }

    func acknowledgeSubmittedTransfer(hash: String, transfer: Transfer) async -> Bool {
        guard let resolved = try? resolveTransfer(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        ) else {
            return false
        }
        guard let identity = try? TonTransferIntentIdentity(
            request: TonNativeEstimateRequest(
                publicKey: resolved.publicKey,
                senderAddress: resolved.senderAddress,
                recipientAddress: resolved.recipientAddress,
                amountNanotons: resolved.amountNanotons,
                bounce: resolved.bounce
            )
        ) else {
            return false
        }
        return await acknowledgeConfirmedTransfer(
            hash: hash,
            senderAddress: resolved.senderAddress,
            identity: identity
        )
    }

    func acknowledgeRecoveredTransfer(
        hash: String,
        identity: TonTransferIntentIdentity
    ) async -> Bool {
        guard let senderAddress = UniversalWalletAccountAddressResolver.address(
            for: chain,
            wallet: wallet
        ),
            let sender = try? TonSwift.Address.parse(senderAddress),
            sender.toRaw() == identity.sender
        else {
            return false
        }
        return await acknowledgeConfirmedTransfer(
            hash: hash,
            senderAddress: senderAddress,
            identity: identity
        )
    }

    private func acknowledgeConfirmedTransfer(
        hash: String,
        senderAddress: String,
        identity: TonTransferIntentIdentity
    ) async -> Bool {
        do {
            try await sendService.acknowledgeConfirmedTransfer(
                senderAddress: senderAddress,
                identity: identity,
                messageHashHex: hash
            )
            return true
        } catch {
            return false
        }
    }

    private func resolveTransfer(
        for transfer: Transfer,
        failure: (String) -> TransferServiceError
    ) throws -> ResolvedTransfer {
        guard transfer.tip == nil, transfer.appId == nil else {
            throw failure("TON tips and app identifiers are not supported")
        }

        guard transfer.chainAsset.chain.chainId == chain.chainId else {
            throw failure("TON transfer chain does not match the selected service")
        }

        let chainId = chain.chainId.lowercased()
        guard !(chain.options ?? []).contains(.testnet),
              chainId == TonChainSelection.mainnetChainId ||
              chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.chainId ||
              chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.id
        else {
            throw failure("Unsupported TON network: \(chain.chainId)")
        }

        let asset = transfer.chainAsset.asset
        guard transfer.chainAsset.isNative,
              asset.isNative,
              asset.isUtility,
              asset.id == UniversalWalletRegistry.tonNativeAssetId ||
              asset.id.uppercased() == "TON",
              asset.symbol.uppercased() == "TON",
              asset.precision == 9,
              asset.type == nil || asset.type == .normal
        else {
            throw failure("Only native TON transfers are supported")
        }

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("TON account address is unavailable for \(chain.chainId)")
        }
        guard let account = wallet.fetch(for: chain.accountRequest()),
              account.publicKey.count == 32
        else {
            throw failure("TON public key is unavailable for \(chain.chainId)")
        }

        let bounce: Bool
        do {
            bounce = try TonTransferTransactionBuilder.requiredBounceFlag(
                forRecipientAddress: transfer.receiver
            )
        } catch {
            throw failure("TON recipient address or bounce policy is invalid")
        }

        return ResolvedTransfer(
            publicKey: account.publicKey,
            senderAddress: sourceAddress,
            recipientAddress: transfer.receiver,
            amountNanotons: transfer.amount.description,
            bounce: bounce
        )
    }
}

final class SolanaTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let rpcClient: SolanaRpcClientProtocol
    private let sendService: SolanaSendService
    private let balanceSync: SolanaBalanceSyncing
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        rpcClient: SolanaRpcClientProtocol? = nil,
        balanceSync: SolanaBalanceSyncing = SolanaBalanceSync(client: SolanaIndexerClient()),
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider()
    ) throws {
        self.wallet = wallet
        self.chain = chain
        if let rpcClient {
            self.rpcClient = rpcClient
        } else {
            self.rpcClient = try SolanaRpcClient()
        }
        self.balanceSync = balanceSync
        self.mnemonicProvider = mnemonicProvider
        let network = try Self.solanaNetwork(for: chain)
        sendService = SolanaSendService(
            rpcClient: self.rpcClient,
            balanceProvider: SolanaTransferBalanceProvider(
                balanceSync: balanceSync,
                network: network,
                baseURL: chain.externalApi?.history?.url.absoluteString
            )
        )
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        let context = try resolveContext(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        if isNativeSolAsset(transfer.chainAsset.asset, network: context.network) {
            return try await estimateNativeFee(for: transfer, context: context)
        }

        return try await estimateTokenFee(for: transfer, context: context)
    }

    private func estimateNativeFee(
        for transfer: Transfer,
        context: SolanaTransferContext
    ) async throws -> BigUInt {
        let lamports = try resolveLamports(
            transfer.amount,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        let blockhash = try await rpcClient.latestBlockhash(
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: context.sourceAddress,
            recipientAddress: transfer.receiver,
            lamports: lamports,
            recentBlockhash: blockhash.value.blockhash
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana transfer fee is unavailable")
        }

        return BigUInt(UInt64(fee))
    }

    private func estimateTokenFee(
        for transfer: Transfer,
        context: SolanaTransferContext
    ) async throws -> BigUInt {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let destinationTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: transfer.receiver,
            mintAddress: token.mintAddress,
            tokenProgram: .splToken
        )
        let destinationTokenAccountExists = try await rpcClient.accountExists(
            address: destinationTokenAccount,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let blockhash = try await rpcClient.latestBlockhash(
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: context.sourceAddress,
            sourceTokenAccount: token.sourceTokenAccount,
            destinationTokenAccount: destinationTokenAccountExists ? destinationTokenAccount : nil,
            mintAddress: token.mintAddress,
            rawAmount: token.rawAmount,
            decimals: token.decimals,
            recentBlockhash: blockhash.value.blockhash,
            tokenProgram: .splToken,
            destinationWalletAddress: destinationTokenAccountExists ? nil : transfer.receiver
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana token transfer fee is unavailable")
        }

        return BigUInt(UInt64(fee))
    }

    func submit(transfer: Transfer) async throws -> String {
        let context = try resolveContext(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        )

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).address
        } catch {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is invalid")
        }

        guard derivedAddress == context.sourceAddress else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic does not match selected wallet")
        }

        if isNativeSolAsset(transfer.chainAsset.asset, network: context.network) {
            return try await submitNative(transfer: transfer, context: context, mnemonic: mnemonic)
        }

        return try await submitToken(transfer: transfer, context: context, mnemonic: mnemonic)
    }

    private func submitNative(
        transfer: Transfer,
        context: SolanaTransferContext,
        mnemonic: String
    ) async throws -> String {
        let lamports = try resolveLamports(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let result = try await sendService.send(
            SolanaSendRequest(
                mnemonic: mnemonic,
                recipientAddress: transfer.receiver,
                lamports: lamports,
                rpcURL: context.rpcURL
            )
        )

        return result.signature
    }

    private func submitToken(
        transfer: Transfer,
        context: SolanaTransferContext,
        mnemonic: String
    ) async throws -> String {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let result = try await sendService.sendTokenTransfer(
            SolanaTokenSendRequest(
                mnemonic: mnemonic,
                sourceTokenAccount: token.sourceTokenAccount,
                mintAddress: token.mintAddress,
                rawAmount: token.rawAmount,
                decimals: token.decimals,
                rpcURL: context.rpcURL,
                tokenProgram: .splToken,
                destinationWalletAddress: transfer.receiver
            )
        )

        return result.signature
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        for _: Transfer,
        failure: (String) -> TransferServiceError
    ) throws -> SolanaTransferContext {
        let network = try Self.solanaNetwork(for: chain)

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Solana account address is unavailable for \(chain.chainId)")
        }

        let normalizedSourceAddress: String
        do {
            normalizedSourceAddress = try SolanaRpcRoutes.normalizePublicKey(sourceAddress)
        } catch {
            throw failure("Solana source address is invalid")
        }

        return SolanaTransferContext(
            sourceAddress: normalizedSourceAddress,
            network: network,
            indexerBaseURL: chain.externalApi?.history?.url.absoluteString,
            rpcURL: rpcURL(for: network)
        )
    }

    private static func solanaNetwork(for chain: ChainModel) throws -> UniversalWalletRegistry.SolanaNetwork {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return UniversalWalletRegistry.solanaMainnet
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return UniversalWalletRegistry.solanaDevnet
        default:
            throw TransferServiceError.transferFailed(reason: "Unsupported Solana chain: \(chain.chainId)")
        }
    }

    private func isNativeSolAsset(
        _ asset: AssetModel,
        network: UniversalWalletRegistry.SolanaNetwork
    ) -> Bool {
        asset.isNative &&
            asset.id.uppercased() == network.nativeAsset.id &&
            asset.symbol.uppercased() == network.nativeAsset.symbol &&
            asset.precision == UInt16(network.nativeAsset.decimals)
    }

    private func resolveLamports(
        _ amount: BigUInt,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Solana transfer amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let lamports = Int64(amount.description)
        else {
            throw failure("Solana transfer amount is too large")
        }

        return lamports
    }

    private func resolveRawAmount(
        _ amount: BigUInt,
        unitName: String,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Solana \(unitName) amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let rawAmount = Int64(amount.description)
        else {
            throw failure("Solana \(unitName) amount is too large")
        }

        return rawAmount
    }

    private func resolveTokenTransferContext(
        for transfer: Transfer,
        context: SolanaTransferContext,
        failure: (String) -> TransferServiceError
    ) async throws -> SolanaTokenTransferContext {
        let rawAmount = try resolveRawAmount(
            transfer.amount,
            unitName: "token raw",
            failure: failure
        )
        let balances = try await balanceSync.balances(
            wallet: context.sourceAddress,
            network: context.network,
            baseURL: context.indexerBaseURL,
            includeTokenMetadata: false
        )
        guard let balance = balances.tokenBalances.first(where: { matchesTokenBalance($0, asset: transfer.chainAsset.asset) }) else {
            throw failure("Solana token balance is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        guard balance.tokenProgram == Self.splTokenProgramName else {
            throw failure("Solana token transfers currently support only SPL Token assets")
        }

        guard let sourceTokenAccount = balance.tokenAccountId?.nonEmpty else {
            throw failure("Solana token source account is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        guard let mintAddress = balance.contractAddress?.nonEmpty ?? balance.assetId.nonEmpty else {
            throw failure("Solana token mint is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        return SolanaTokenTransferContext(
            sourceTokenAccount: sourceTokenAccount,
            mintAddress: mintAddress,
            decimals: balance.decimals,
            rawAmount: rawAmount
        )
    }

    private func matchesTokenBalance(
        _ balance: UniversalWalletIndexedAssetBalance,
        asset: AssetModel
    ) -> Bool {
        guard !balance.isNative, balance.decimals == Int(asset.precision) else {
            return false
        }

        let identifiers = [asset.id, asset.currencyId].compactMap { $0?.nonEmpty }
        return identifiers.contains { $0 == balance.assetId || $0 == balance.contractAddress }
    }

    private func rpcURL(for network: UniversalWalletRegistry.SolanaNetwork) -> String {
        if let selectedNode = chain.selectedNode?.url.absoluteString {
            return selectedNode
        }

        return chain.nodes
            .sorted { $0.url.absoluteString < $1.url.absoluteString }
            .first?
            .url
            .absoluteString ?? network.rpcURL.absoluteString
    }

    private static let splTokenProgramName = "spl-token"
}

protocol IrohaTransferSigning {
    func buildAndSignTransfer(_ request: IrohaTransferSigningRequest) async throws -> IrohaSignedTransfer
}

struct UnavailableIrohaTransferSigner: IrohaTransferSigning {
    func buildAndSignTransfer(_: IrohaTransferSigningRequest) async throws -> IrohaSignedTransfer {
        throw TransferServiceError.transferFailed(reason: "Iroha transfer signing codec is unavailable")
    }
}

enum IrohaWalletSmokeMetadataError: Error, Equatable {
    case invalidFieldSet
    case invalidEvidenceRole
    case invalidRouteGovernanceActionHash
    case invalidWalletPlatform
    case invalidWalletCommit
}

struct IrohaWalletSmokeTransactionMetadata: Equatable {
    static let evidenceRoleKey = "evidence_role"
    static let routeGovernanceActionHashKey = "route_governance_action_hash"
    static let walletPlatformKey = "wallet_platform"
    static let walletCommitKey = "wallet_commit"

    private static let expectedKeys: Set<String> = [
        evidenceRoleKey,
        routeGovernanceActionHashKey,
        walletPlatformKey,
        walletCommitKey
    ]
    private static let routeHashPrefix = "sha256:"

    private let snapshot: [String: String]

    static func validatedSnapshot(
        of untrustedMetadata: [String: String]
    ) throws -> IrohaWalletSmokeTransactionMetadata {
        guard untrustedMetadata.count == expectedKeys.count,
              Set(untrustedMetadata.keys) == expectedKeys
        else {
            throw IrohaWalletSmokeMetadataError.invalidFieldSet
        }

        guard untrustedMetadata[evidenceRoleKey] == "wallet-smoke" else {
            throw IrohaWalletSmokeMetadataError.invalidEvidenceRole
        }
        guard untrustedMetadata[walletPlatformKey] == "ios" else {
            throw IrohaWalletSmokeMetadataError.invalidWalletPlatform
        }

        guard let routeHash = untrustedMetadata[routeGovernanceActionHashKey],
              routeHash.hasPrefix(routeHashPrefix),
              routeHash.utf8.count == routeHashPrefix.utf8.count + 64,
              isLowercaseHex(routeHash.utf8.dropFirst(routeHashPrefix.utf8.count)),
              routeHash != routeHashPrefix + String(repeating: "0", count: 64)
        else {
            throw IrohaWalletSmokeMetadataError.invalidRouteGovernanceActionHash
        }

        guard let walletCommit = untrustedMetadata[walletCommitKey],
              walletCommit.utf8.count == 40,
              isLowercaseHex(walletCommit.utf8),
              walletCommit != String(repeating: "0", count: 40)
        else {
            throw IrohaWalletSmokeMetadataError.invalidWalletCommit
        }

        // Copy every String into a fresh dictionary before crossing the async signer
        // boundary. Later copy-on-write mutation of the operator input cannot alter it.
        return IrohaWalletSmokeTransactionMetadata(
            snapshot: Dictionary(uniqueKeysWithValues: untrustedMetadata.map { ($0.key, $0.value) })
        )
    }

    var values: [String: String] {
        snapshot
    }

    private init(snapshot: [String: String]) {
        self.snapshot = snapshot
    }

    private static func isLowercaseHex<C: Collection>(_ bytes: C) -> Bool where C.Element == UInt8 {
        !bytes.isEmpty && bytes.allSatisfy { byte in
            (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a") ... UInt8(ascii: "f")).contains(byte)
        }
    }
}

enum IrohaTransactionMetadata: Equatable {
    case none
    case walletSmoke(IrohaWalletSmokeTransactionMetadata)

    var values: [String: String] {
        switch self {
        case .none:
            return [:]
        case let .walletSmoke(metadata):
            return metadata.values
        }
    }
}

struct IrohaTransferSigningRequest: Equatable {
    let amount: String
    let assetDefinitionId: String
    let authority: String
    let chainId: String
    let derivationPath: String
    let destinationAccountId: String
    let metadata: IrohaTransactionMetadata
    let mnemonicOrSeed: String
    let network: String
    let signingPublicKeyHex: String
    let sourceAccountId: String
    let sourceAssetId: String
}

struct IrohaSignedTransfer: Equatable {
    let signedTransaction: Data
    let transactionHashHex: String?
}

final class IrohaTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let toriiClient: IrohaToriiClientProtocol
    private let signer: IrohaTransferSigning
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        toriiClient: IrohaToriiClientProtocol = IrohaToriiClient(),
        signer: IrohaTransferSigning = UnavailableIrohaTransferSigner(),
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider()
    ) {
        self.wallet = wallet
        self.chain = chain
        self.toriiClient = toriiClient
        self.signer = signer
        self.mnemonicProvider = mnemonicProvider
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        _ = try resolveContext(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        return .zero
    }

    func submit(transfer: Transfer) async throws -> String {
        try await submitValidated(transfer: transfer, metadata: .none)
    }

    /// Operator evidence hook only. This does not install a signer, enable Nexus,
    /// or make the standard `TransferServiceProtocol` route metadata-capable.
    func submitNexusWalletSmokeEvidence(
        transfer: Transfer,
        untrustedMetadata: [String: String]
    ) async throws -> String {
        let metadata = try IrohaWalletSmokeTransactionMetadata.validatedSnapshot(
            of: untrustedMetadata
        )
        guard chain.chainId == UniversalWalletRegistry.nexus.chainId else {
            throw TransferServiceError.transferFailed(
                reason: "Iroha wallet-smoke evidence requires the exact canonical Nexus chain identity"
            )
        }
        let evidenceToriiBaseURL = try Self.toriiBaseURL(
            for: chain,
            network: UniversalWalletRegistry.nexus,
            failure: TransferServiceError.transferFailed(reason:)
        )
        guard evidenceToriiBaseURL == UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString else {
            throw TransferServiceError.transferFailed(
                reason: "Iroha wallet-smoke evidence requires the canonical Nexus Torii endpoint"
            )
        }

        return try await submitValidated(
            transfer: transfer,
            metadata: .walletSmoke(metadata)
        )
    }

    private func submitValidated(
        transfer: Transfer,
        metadata: IrohaTransactionMetadata
    ) async throws -> String {
        let context = try resolveContext(
            for: transfer,
            metadata: metadata,
            failure: TransferServiceError.transferFailed(reason:)
        )

        if case .walletSmoke = metadata {
            guard context.signingRequest.network == "nexus" else {
                throw TransferServiceError.transferFailed(
                    reason: "Iroha wallet-smoke evidence is restricted to Nexus"
                )
            }
            guard context.toriiBaseURL == UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString else {
                throw TransferServiceError.transferFailed(
                    reason: "Iroha wallet-smoke evidence requires the canonical Nexus Torii endpoint"
                )
            }
        }

        let signedTransfer = try await signer.buildAndSignTransfer(context.signingRequest)

        guard !signedTransfer.signedTransaction.isEmpty else {
            throw TransferServiceError.transferFailed(reason: "Iroha transfer signer returned an empty transaction")
        }

        let receipt = try await toriiClient.submitTransaction(
            noritoBytes: signedTransfer.signedTransaction,
            baseURL: context.toriiBaseURL
        )

        return signedTransfer.transactionHashHex
            ?? receipt.payload.signedTransactionHash
            ?? receipt.payload.txHash
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        for transfer: Transfer,
        metadata: IrohaTransactionMetadata = .none,
        failure: (String) -> TransferServiceError
    ) throws -> IrohaTransferContext {
        let network = try Self.irohaNetwork(
            for: chain,
            failure: failure
        )
        let toriiBaseURL = try Self.toriiBaseURL(
            for: chain,
            network: network,
            failure: failure
        )

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Iroha account address is unavailable for \(chain.chainId)")
        }

        let sourceDetails: IrohaAddressDetails
        do {
            sourceDetails = try IrohaAddressCodec.parse(
                sourceAddress,
                expectedDiscriminant: network.chainDiscriminant
            )
        } catch {
            throw failure("Iroha source address is invalid")
        }

        let destinationAddress: String
        do {
            destinationAddress = try IrohaAddressCodec.parse(
                transfer.receiver,
                expectedDiscriminant: network.chainDiscriminant
            ).i105
        } catch {
            throw failure("Iroha recipient address is invalid")
        }

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw failure("Iroha mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try IrohaKeyDerivation.deriveAddress(
                mnemonic: mnemonic,
                chainDiscriminant: network.chainDiscriminant
            ).i105
        } catch {
            throw failure("Iroha mnemonic root material is invalid")
        }

        guard derivedAddress == sourceDetails.i105 else {
            throw failure("Iroha mnemonic does not match selected wallet")
        }

        let assetDefinitionId = try Self.normalizeAssetDefinitionId(
            transfer.chainAsset.asset.id,
            failure: failure
        )
        let amount = try Self.normalizeAmount(
            rawAmount: transfer.amount,
            precision: Int(transfer.chainAsset.asset.precision),
            failure: failure
        )

        return IrohaTransferContext(
            toriiBaseURL: toriiBaseURL,
            signingRequest: IrohaTransferSigningRequest(
                amount: amount,
                assetDefinitionId: assetDefinitionId,
                authority: sourceDetails.i105,
                chainId: network.chainId,
                derivationPath: UniversalWalletDerivationPaths.irohaDefault,
                destinationAccountId: destinationAddress,
                metadata: metadata,
                mnemonicOrSeed: mnemonic,
                network: Self.networkKey(for: network),
                signingPublicKeyHex: sourceDetails.publicKeyHex,
                sourceAccountId: sourceDetails.i105,
                sourceAssetId: "\(assetDefinitionId)#\(sourceDetails.i105)"
            )
        )
    }

    private static func irohaNetwork(
        for chain: ChainModel,
        failure: (String) -> TransferServiceError
    ) throws -> UniversalWalletRegistry.IrohaNetwork {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return UniversalWalletRegistry.nexus
        default:
            throw failure("Unsupported Iroha chain: \(chain.chainId)")
        }
    }

    private static func toriiBaseURL(
        for chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        if let url = chain.externalApi?.history?.url.absoluteString.nonEmpty {
            return url
        }

        guard let url = network.toriiBaseURL?.absoluteString.nonEmpty else {
            throw failure("Iroha Torii endpoint is not configured for \(chain.chainId)")
        }

        return url
    }

    private static func normalizeAmount(
        rawAmount: BigUInt,
        precision: Int,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        guard rawAmount > .zero else {
            throw failure("Iroha transfer amount must be positive")
        }

        guard precision >= 0, precision <= 28 else {
            throw failure("Iroha asset precision is unsupported")
        }

        let raw = rawAmount.description
        guard precision > 0 else {
            return raw
        }

        let padded = raw.count <= precision
            ? String(repeating: "0", count: precision - raw.count + 1) + raw
            : raw
        let splitIndex = padded.index(padded.endIndex, offsetBy: -precision)
        let whole = String(padded[..<splitIndex])
        var fraction = String(padded[splitIndex...])
        while fraction.last == "0" {
            fraction.removeLast()
        }

        return fraction.isEmpty ? whole : "\(whole).\(fraction)"
    }

    private static func normalizeAssetDefinitionId(
        _ assetDefinitionId: String,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        let pattern = #"^[^\s%/?:#]+#[^\s%/?:#]+$"#
        guard assetDefinitionId.range(of: pattern, options: .regularExpression) != nil else {
            throw failure("Iroha asset definition id is invalid")
        }

        return assetDefinitionId
    }

    private static func networkKey(for network: UniversalWalletRegistry.IrohaNetwork) -> String {
        if network == UniversalWalletRegistry.taira {
            return "taira"
        }

        if network == UniversalWalletRegistry.nexus {
            return "nexus"
        }

        return network.id
    }
}

private struct BitcoinTransferContext {
    let sourceAddress: String
    let network: BitcoinIndexerNetwork
    let baseURL: String?
}

private struct SolanaTransferContext {
    let sourceAddress: String
    let network: UniversalWalletRegistry.SolanaNetwork
    let indexerBaseURL: String?
    let rpcURL: String
}

private struct SolanaTokenTransferContext {
    let sourceTokenAccount: String
    let mintAddress: String
    let decimals: Int
    let rawAmount: Int64
}

private struct IrohaTransferContext {
    let toriiBaseURL: String
    let signingRequest: IrohaTransferSigningRequest
}

private final class SolanaTransferBalanceProvider: SolanaSendBalanceProvider {
    private let balanceSync: SolanaBalanceSyncing
    private let network: UniversalWalletRegistry.SolanaNetwork
    private let baseURL: String?

    init(
        balanceSync: SolanaBalanceSyncing,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String?
    ) {
        self.balanceSync = balanceSync
        self.network = network
        self.baseURL = baseURL
    }

    func balances(wallet: String) async throws -> SolanaBalanceSyncResult {
        try await balanceSync.balances(
            wallet: wallet,
            network: network,
            baseURL: baseURL,
            includeTokenMetadata: false
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
