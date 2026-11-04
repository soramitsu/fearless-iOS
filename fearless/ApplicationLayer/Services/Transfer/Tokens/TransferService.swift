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

/// Bitcoin prices by size, so the confirm screen shows the rate of the exact quote (sat/vB)
/// next to the fee.
protocol BitcoinTransferFeeRateListener: TransferFeeEstimationListener {
    func didReceiveBitcoinFee(fee: BigUInt, feeRateSatPerVbyte: Double)
}

/// A Solana token transfer to a holder without a token account also pays the rent-exempt
/// deposit that opens it. `fee` includes it (the sender's SOL pays both); the confirm screen
/// names it on its own row.
protocol SolanaTransferFeeBreakdownListener: TransferFeeEstimationListener {
    func didReceiveSolanaFee(fee: BigUInt, accountCreationDeposit: BigUInt)
}

enum TransferServiceError: Error {
    case cannotEstimateFee(reason: String)
    case transferFailed(reason: String)
    case tonProductionSendDisabled
    case tonPriorTransferConfirmed(identity: TonTransferIntentIdentity, messageHashHex: String)
    case tonBroadcastOutcomeUnknown(messageHashHex: String)
    case bitcoinSendPaused
    case solanaSendPaused
    /// The signed transaction may have reached the Bitcoin network; the wallet kept it and
    /// must not build another payment from other coins until it knows.
    case bitcoinBroadcastOutcomeUnknown(txid: String)
    /// An earlier transfer is still unresolved, so this one was not built or sent.
    case bitcoinPriorTransferUnresolved(txid: String)
    /// An earlier transfer turned out to have been sent, so this one was not built or sent.
    case bitcoinPriorTransferConfirmed(txid: String)
    /// Nothing left the wallet, and the reason is known.
    case bitcoinTransferNotSent(BitcoinTransferNotSentReason)
    /// The signed Solana transaction may have reached the cluster. Nothing new is signed until
    /// it lands or its blockhash expires, about a minute later.
    case solanaBroadcastOutcomeUnknown(signature: String)
    /// An earlier Solana transfer could still land, so this one was not signed or sent.
    case solanaPriorTransferUnresolved(signature: String)
    /// Original cluster identity is absent or differs; keep the record without lookup or replay.
    case solanaRecoveryUnavailable(signature: String)
    /// Preserved pending-payment data is unreadable; no trustworthy ID or outcome is available.
    case solanaRecoveryRecordUnreadable
    /// An earlier Solana transfer whose outcome was unknown did land; this one was not sent.
    case solanaPriorTransferConfirmed(signature: String)
    /// An earlier Solana transfer reported as sent expired or failed without moving the
    /// amount; this one was not sent either.
    case solanaPriorTransferNotSent(signature: String)
    /// Nothing left the wallet for this Solana transfer, and the reason is known.
    case solanaTransferNotSent(SolanaTransferNotSentReason)
    /// This Solana transfer's blockhash expired, but too few nodes could prove it never
    /// landed. Nothing more is retried; the user checks the balance and the transaction.
    case solanaTransferUnverified(signature: String)
    /// An earlier Solana transfer's blockhash expired, but too few nodes could prove it never
    /// landed, so this one was not signed or sent. Confirming again sends it.
    case solanaPriorTransferUnverified(signature: String)
    /// The cluster processed the transfer and it failed: the amount did not move; the network
    /// fee was paid.
    case solanaTransferFailed(signature: String)
    case unexpected
}

enum BitcoinTransferNotSentReason: Equatable {
    /// No Bitcoin service could be reached.
    case noConnection
    /// A node refused the transaction.
    case rejectedByNetwork
    /// The coins of the earlier, unresolved transfer were spent by another transaction.
    case coinsAlreadySpent
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
    /// Broadcasts the already signed transaction `hash` again; never builds a new one.
    func retryUnresolvedTransfer(hash: String) async throws -> String
    /// Lets the next transfer replace the unresolved transaction `hash` by spending its coins.
    func allowReplacingUnresolvedTransfer(hash: String) async -> Bool

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
    func retryUnresolvedTransfer(hash _: String) async throws -> String {
        throw TransferServiceError.unexpected
    }

    func allowReplacingUnresolvedTransfer(hash _: String) async -> Bool { false }
}

private struct BitcoinTransferFeeQuoteIdentity: Equatable {
    let amountSats: Int64
    let recipientAddress: String
    let sourceAddress: String
    let network: BitcoinIndexerNetwork
    let baseURL: String?
}

private struct BitcoinTransferFeeQuote {
    let identity: BitcoinTransferFeeQuoteIdentity
    let feeRateSatPerVbyte: Double
    let feeSats: Int64
    /// The coins the quoted plan had to spend because it replaces an unresolved transfer.
    let requiredOutpoints: Set<BitcoinOutpoint>
}

/// One transfer at a time per wallet and network: a second `submit` racing the first could
/// read the coin set before the first has recorded what it is about to spend.
private final class BitcoinSubmissionRegistry {
    static let shared = BitcoinSubmissionRegistry()

    private let lock = NSLock()
    private var active = Set<BitcoinPendingBroadcastScope>()

    func begin(_ scope: BitcoinPendingBroadcastScope) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return active.insert(scope).inserted
    }

    func end(_ scope: BitcoinPendingBroadcastScope) {
        lock.lock()
        defer { lock.unlock() }
        active.remove(scope)
    }
}

private final class BitcoinTransferFeeQuoteStore {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var pendingIdentity: BitcoinTransferFeeQuoteIdentity?
    private var quote: BitcoinTransferFeeQuote?

    func begin(identity: BitcoinTransferFeeQuoteIdentity) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation = generation == UInt64.max ? 1 : generation + 1
        pendingIdentity = identity
        quote = nil
        return generation
    }

    func commit(
        _ quote: BitcoinTransferFeeQuote,
        generation expectedGeneration: UInt64
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard
            generation == expectedGeneration,
            pendingIdentity == quote.identity
        else {
            return false
        }
        self.quote = quote
        return true
    }

    func fail(generation expectedGeneration: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration else {
            return
        }
        pendingIdentity = nil
        quote = nil
    }

    func consume(identity: BitcoinTransferFeeQuoteIdentity) -> BitcoinTransferFeeQuote? {
        lock.lock()
        defer { lock.unlock() }
        guard pendingIdentity == identity, quote?.identity == identity else {
            return nil
        }
        let result = quote
        pendingIdentity = nil
        quote = nil
        return result
    }
}

final class BitcoinTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let planner: BitcoinSendPlanner
    private let sendService: BitcoinSendService
    private let balanceSync: BitcoinBalanceSync
    private let mnemonicProvider: BitcoinMnemonicProviding
    private let sendGate: UniversalSendGate
    private let pendingStore: BitcoinPendingBroadcastStoring
    private let feeQuoteStore = BitcoinTransferFeeQuoteStore()
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        client: BitcoinIndexerClientProtocol = BitcoinFailoverIndexerClient(),
        mnemonicProvider: BitcoinMnemonicProviding = KeychainBitcoinMnemonicProvider(),
        sendGate: UniversalSendGate = .production,
        pendingStore: BitcoinPendingBroadcastStoring = BitcoinPendingBroadcastStore.shared,
        statusPolling: BitcoinSendService.StatusPolling = .standard
    ) {
        self.wallet = wallet
        self.chain = chain
        planner = BitcoinSendPlanner(client: client)
        sendService = BitcoinSendService(client: client, pendingStore: pendingStore, statusPolling: statusPolling)
        balanceSync = BitcoinBalanceSync(
            discovery: BitcoinReceiveDiscovery(client: client)
        )
        self.mnemonicProvider = mnemonicProvider
        self.sendGate = sendGate
        self.pendingStore = pendingStore
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        BigUInt(UInt64(try await estimateFeeQuote(for: transfer).feeSats))
    }

    private func estimateFeeQuote(for transfer: Transfer) async throws -> (feeSats: Int64, feeRateSatPerVbyte: Double) {
        let context = try resolveContext(failure: TransferServiceError.cannotEstimateFee(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let quoteIdentity = try resolveFeeQuoteIdentity(
            transfer: transfer,
            amountSats: amountSats,
            context: context,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let generation = feeQuoteStore.begin(identity: quoteIdentity)

        do {
            guard let secret = try resolveMnemonic(
                context: context,
                required: true,
                failure: TransferServiceError.cannotEstimateFee(reason:)
            ) else {
                throw TransferServiceError.cannotEstimateFee(
                    reason: "Bitcoin mnemonic root material is unavailable"
                )
            }
            let sources = try await resolveSpendSources(
                context: context,
                secret: secret,
                failure: TransferServiceError.cannotEstimateFee(reason:)
            )
            // A transfer that replaces an unresolved one must spend that one's coins, so the
            // fee shown is the fee of exactly that transaction.
            var requiredOutpoints = replacementOutpoints(for: context)
            let plan: BitcoinSendPlan
            do {
                plan = try await planQuote(
                    amountSats: amountSats,
                    sources: sources,
                    quoteIdentity: quoteIdentity,
                    context: context,
                    requiredOutpoints: requiredOutpoints
                )
            } catch BitcoinUtxoSelectionError.requiredInputUnavailable {
                // One of those coins is gone, so the unresolved transfer is about to resolve;
                // `submit` finds out how before it builds anything.
                requiredOutpoints = []
                plan = try await planQuote(
                    amountSats: amountSats,
                    sources: sources,
                    quoteIdentity: quoteIdentity,
                    context: context,
                    requiredOutpoints: requiredOutpoints
                )
            } catch BitcoinUtxoSelectionError.insufficientFunds {
                // "Max" asks for the whole spendable balance before it can know the fee. Answer
                // with the fee of sending everything; the amount that fits is the balance minus
                // this fee, and the confirm screen quotes that amount again.
                let maxSend = try await planner.maxSend(
                    sources: sources,
                    recipientAddress: quoteIdentity.recipientAddress,
                    network: context.network,
                    baseURL: context.baseURL
                )
                guard amountSats <= maxSend.spendableSats, maxSend.maxAmountSats >= maxSend.minimumAmountSats else {
                    throw BitcoinUtxoSelectionError.insufficientFunds
                }
                try Task.checkCancellation()
                feeQuoteStore.fail(generation: generation)
                return (maxSend.feeSats, maxSend.feeRateSatPerVbyte)
            }
            try Task.checkCancellation()
            let quote = BitcoinTransferFeeQuote(
                identity: quoteIdentity,
                feeRateSatPerVbyte: plan.feeRateSatPerVbyte,
                feeSats: plan.feeSats,
                requiredOutpoints: Set(requiredOutpoints)
            )
            guard feeQuoteStore.commit(quote, generation: generation) else {
                throw TransferServiceError.cannotEstimateFee(
                    reason: "Bitcoin fee quote was superseded"
                )
            }

            return (plan.feeSats, plan.feeRateSatPerVbyte)
        } catch {
            feeQuoteStore.fail(generation: generation)
            throw error
        }
    }

    func submit(transfer: Transfer) async throws -> String {
        // A remote veto that arrived after the fee was quoted must stop the transfer before
        // any key access, signing or broadcast.
        try sendGate.requireTransfer(on: .bitcoin)
        let context = try resolveContext(failure: TransferServiceError.transferFailed(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let quoteIdentity = try resolveFeeQuoteIdentity(
            transfer: transfer,
            amountSats: amountSats,
            context: context,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let scope = pendingScope
        guard BitcoinSubmissionRegistry.shared.begin(scope) else {
            throw TransferServiceError.transferFailed(
                reason: "Another Bitcoin transfer from this wallet is still being sent"
            )
        }
        defer { BitcoinSubmissionRegistry.shared.end(scope) }

        // Double-pay guard. If an earlier transfer may still be in flight, nothing is planned or
        // signed: a new plan would pick other coins, and both payments could confirm.
        let replacing = try await requireNoTransferInFlight(scope: scope, context: context)
        guard let quote = feeQuoteStore.consume(identity: quoteIdentity) else {
            throw TransferServiceError.transferFailed(
                reason: "Bitcoin fee quote is missing or expired; review the fee again"
            )
        }
        let requiredOutpoints = replacing?.inputs.map(\.outpoint.normalized) ?? []
        guard quote.requiredOutpoints == Set(requiredOutpoints) else {
            throw TransferServiceError.transferFailed(
                reason: "Bitcoin fee quote no longer matches the coins to spend; review the fee again"
            )
        }

        guard let secret = try resolveMnemonic(
            context: context,
            required: true,
            failure: TransferServiceError.transferFailed(reason:)
        ) else {
            throw TransferServiceError.transferFailed(
                reason: "Bitcoin mnemonic root material is unavailable"
            )
        }
        let sources = try await resolveSpendSources(
            context: context,
            secret: secret,
            failure: TransferServiceError.transferFailed(reason:)
        )

        let result: BitcoinSentTransaction
        do {
            result = try await sendService.send(
                BitcoinSendRequest(
                    mnemonic: secret.mnemonic,
                    amountSats: amountSats,
                    sources: sources,
                    recipientAddress: quoteIdentity.recipientAddress,
                    passphrase: secret.passphrase,
                    changeAddress: context.sourceAddress,
                    feeRateSatPerVbyte: quote.feeRateSatPerVbyte,
                    expectedFeeSats: quote.feeSats,
                    requiredOutpoints: requiredOutpoints,
                    network: context.network,
                    baseURL: context.baseURL
                ),
                scope: scope,
                replacing: replacing
            )
        } catch BitcoinUtxoSelectionError.requiredInputUnavailable {
            // The replacement can no longer spend the earlier transfer's coins, so it could not
            // conflict with it. Stay blocked until the indexers show what spent them.
            throw TransferServiceError.bitcoinPriorTransferUnresolved(txid: replacing?.txid ?? "")
        } catch let error as BitcoinSendServiceError {
            await invalidateBalance(for: context)
            throw Self.transferError(for: error)
        }

        await invalidateBalance(for: context)

        return result.broadcastTxid
    }

    func retryUnresolvedTransfer(hash: String) async throws -> String {
        try sendGate.requireTransfer(on: .bitcoin)
        let context = try resolveContext(failure: TransferServiceError.transferFailed(reason:))
        let scope = pendingScope
        guard let record = pendingStore.pending(for: scope), record.txid == hash else {
            throw TransferServiceError.transferFailed(reason: "There is no unresolved Bitcoin transfer to retry")
        }
        guard BitcoinSubmissionRegistry.shared.begin(scope) else {
            throw TransferServiceError.transferFailed(
                reason: "Another Bitcoin transfer from this wallet is still being sent"
            )
        }
        defer { BitcoinSubmissionRegistry.shared.end(scope) }

        do {
            let txid = try await sendService.rebroadcast(
                record,
                scope: scope,
                network: context.network,
                baseURL: context.baseURL
            )
            await invalidateBalance(for: context)
            return txid
        } catch let error as BitcoinSendServiceError {
            await invalidateBalance(for: context)
            throw Self.transferError(for: error)
        }
    }

    func allowReplacingUnresolvedTransfer(hash: String) async -> Bool {
        let scope = pendingScope
        guard var record = pendingStore.pending(for: scope), record.txid == hash else {
            return false
        }
        record.replacementAllowedAt = Date()
        do {
            try pendingStore.save(record, for: scope)
            return true
        } catch {
            return false
        }
    }

    private var pendingScope: BitcoinPendingBroadcastScope {
        BitcoinPendingBroadcastScope(walletId: wallet.metaId, chainId: chain.chainId)
    }

    /// Returns the unresolved transfer the user chose to replace, or `nil` when nothing is in
    /// flight. Throws when an earlier transfer was sent after all, or is unresolved and the
    /// user has not chosen what to do about it.
    private func requireNoTransferInFlight(
        scope: BitcoinPendingBroadcastScope,
        context: BitcoinTransferContext
    ) async throws -> BitcoinPendingBroadcast? {
        switch await sendService.checkPending(scope: scope, network: context.network, baseURL: context.baseURL) {
        case .none:
            return nil
        case let .sent(txid):
            await invalidateBalance(for: context)
            throw TransferServiceError.bitcoinPriorTransferConfirmed(txid: txid)
        case let .unresolved(record):
            guard record.replacementAllowedAt != nil else {
                throw TransferServiceError.bitcoinPriorTransferUnresolved(txid: record.txid)
            }
            return record
        }
    }

    private func replacementOutpoints(for _: BitcoinTransferContext) -> [BitcoinOutpoint] {
        guard let record = pendingStore.pending(for: pendingScope), record.replacementAllowedAt != nil else {
            return []
        }
        return record.inputs.map(\.outpoint.normalized)
    }

    private func planQuote(
        amountSats: Int64,
        sources: [BitcoinUtxoSource],
        quoteIdentity: BitcoinTransferFeeQuoteIdentity,
        context: BitcoinTransferContext,
        requiredOutpoints: [BitcoinOutpoint]
    ) async throws -> BitcoinSendPlan {
        try await planner.plan(
            amountSats: amountSats,
            sources: sources,
            recipientAddress: quoteIdentity.recipientAddress,
            changeAddress: context.sourceAddress,
            requiredOutpoints: requiredOutpoints,
            network: context.network,
            baseURL: context.baseURL
        )
    }

    private func invalidateBalance(for context: BitcoinTransferContext) async {
        await BitcoinWalletBalanceCache.shared.invalidate(
            balanceCacheKey(for: context)
        )
    }

    private static func transferError(for error: BitcoinSendServiceError) -> TransferServiceError {
        switch error {
        case let .broadcastOutcomeUnknown(txid):
            return .bitcoinBroadcastOutcomeUnknown(txid: txid)
        case let .replacedTransferSent(txid):
            return .bitcoinPriorTransferConfirmed(txid: txid)
        case .broadcastNotSent:
            return .bitcoinTransferNotSent(.noConnection)
        case .broadcastRejected:
            return .bitcoinTransferNotSent(.rejectedByNetwork)
        case .pendingTransferCannotConfirm:
            return .bitcoinTransferNotSent(.coinsAlreadySpent)
        case .feeQuoteMismatch:
            return .transferFailed(reason: "Bitcoin fee changed since it was quoted; review the fee again")
        case .pendingBroadcastNotRecorded, .plannedTransactionMismatch, .replacementDoesNotConflict:
            return .transferFailed(reason: "Bitcoin transfer could not be prepared safely; nothing was sent")
        }
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let quote = try await self.estimateFeeQuote(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                let fee = BigUInt(UInt64(quote.feeSats))
                if let listener = listener as? BitcoinTransferFeeRateListener {
                    listener.didReceiveBitcoinFee(fee: fee, feeRateSatPerVbyte: quote.feeRateSatPerVbyte)
                } else {
                    listener?.didReceiveFee(fee: fee)
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
            baseURL: indexerNetwork.defaultBaseURL.absoluteString
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

    private func resolveFeeQuoteIdentity(
        transfer: Transfer,
        amountSats: Int64,
        context: BitcoinTransferContext,
        failure: (String) -> TransferServiceError
    ) throws -> BitcoinTransferFeeQuoteIdentity {
        let keyNetwork = bitcoinKeyDerivationNetwork(for: context.network)
        guard let recipient = BitcoinAddressSupport.recipient(transfer.receiver, network: keyNetwork) else {
            throw failure("Bitcoin recipient address is invalid")
        }

        return BitcoinTransferFeeQuoteIdentity(
            amountSats: amountSats,
            recipientAddress: recipient.address,
            sourceAddress: context.sourceAddress,
            network: context.network,
            baseURL: context.baseURL
        )
    }

    private func resolveMnemonic(
        context: BitcoinTransferContext,
        required: Bool,
        failure: (String) -> TransferServiceError
    ) throws -> UniversalWalletSecret? {
        let secret: UniversalWalletSecret?
        do {
            secret = try mnemonicProvider.secret(for: wallet, chain: chain)
        } catch {
            throw failure("Bitcoin mnemonic root material is unavailable")
        }

        guard let secret else {
            if required {
                throw failure("Bitcoin mnemonic root material is unavailable")
            }
            return nil
        }

        let derivedAddress: String
        do {
            derivedAddress = try BitcoinKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic,
                passphrase: secret.passphrase,
                network: bitcoinKeyDerivationNetwork(for: context.network)
            ).firstReceiveAddress
        } catch {
            throw failure("Bitcoin mnemonic root material is invalid")
        }

        guard derivedAddress.caseInsensitiveCompare(context.sourceAddress) == .orderedSame else {
            throw failure("Bitcoin mnemonic does not match selected wallet")
        }

        return secret
    }

    private func resolveSpendSources(
        context: BitcoinTransferContext,
        secret: UniversalWalletSecret?,
        failure: (String) -> TransferServiceError
    ) async throws -> [BitcoinUtxoSource] {
        let firstSource = BitcoinUtxoSource(
            address: context.sourceAddress,
            derivationPath: bitcoinKeyDerivationNetwork(for: context.network).firstReceivePath
        )
        guard let secret else {
            return [firstSource]
        }

        do {
            let keyNetwork = bitcoinKeyDerivationNetwork(for: context.network)
            let result = try await BitcoinWalletBalanceCache.shared.value(
                for: balanceCacheKey(for: context),
                staleOnFailure: true
            ) {
                try await self.balanceSync.balance(
                    mnemonic: secret.mnemonic,
                    passphrase: secret.passphrase,
                    network: keyNetwork,
                    baseURL: context.baseURL,
                    gapLimit: nil,
                    maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
                )
            }
            let fundedSources = BitcoinBalanceSync.spendSources(in: result.discovery).map {
                BitcoinUtxoSource(address: $0.address, derivationPath: $0.path)
            }

            return fundedSources.isEmpty ? [firstSource] : fundedSources
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw failure("Bitcoin spendable-address discovery failed")
        }
    }

    private func balanceCacheKey(
        for context: BitcoinTransferContext
    ) -> BitcoinWalletBalanceCache.Key {
        let network = bitcoinNetwork(for: chain)
        return BitcoinWalletBalanceCache.Key(
            walletId: wallet.metaId,
            network: context.network,
            baseURL: context.baseURL,
            gapLimit: network?.defaultGapLimit
                ?? UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit,
            maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
        )
    }

    private func bitcoinNetwork(for chain: ChainModel) -> UniversalWalletRegistry.BitcoinNetwork? {
        UniversalWalletRegistry.bitcoinNetwork(for: chain.chainId)
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
              fee == BigUInt(quote.requiredTonNanotons),
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
        let jetton: TonJettonTransferDetails?

        var request: TonNativeEstimateRequest {
            TonNativeEstimateRequest(
                asset: jetton.map { .jetton(masterAddress: $0.masterAddress) } ?? .nativeTon,
                publicKey: publicKey,
                senderAddress: senderAddress,
                recipientAddress: recipientAddress,
                amountNanotons: amountNanotons,
                bounce: bounce,
                jetton: jetton
            )
        }
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
        pendingCoordinator: TonPendingIntentCoordinator = .shared,
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
        let resolved = try await resolveTransfer(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        do {
            let estimateRequest = resolved.request
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
                    fee: BigUInt(quote.requiredTonNanotons),
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
            guard wallet.legacyTonAccount != nil else { throw TransferServiceError.tonProductionSendDisabled }
        #endif
        let resolved = try await resolveTransfer(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        )

        let identity = try TonTransferIntentIdentity(
            request: resolved.request
        )
        // Atomically consume the exact quote. A nil quote is still passed through so
        // TonSendService can recover an already-persisted same-intent BOC after restart;
        // a genuinely fresh unquoted send fails before signing or remote work.
        let feeQuote = feeQuoteStore.consume(identity: identity)

        do {
            return try await sendService.send(
                resolved.request,
                feeQuote: feeQuote,
                legacyAccount: wallet.legacyTonAccount,
                signingCredentials: {
                    try self.mnemonicProvider.tonSigningCredentials(for: self.wallet, chain: self.chain)
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
        guard let resolved = try? await resolveTransfer(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        ) else {
            return false
        }
        guard let identity = try? TonTransferIntentIdentity(
            request: resolved.request
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

    static func supportsAsset(_ chainAsset: ChainAsset, allowLegacyJettons: Bool) -> Bool {
        let asset = chainAsset.asset
        if chainAsset.isNative, asset.isNative, asset.isUtility,
           asset.id == UniversalWalletRegistry.tonNativeAssetId || asset.id.uppercased() == "TON",
           asset.symbol.uppercased() == "TON", asset.precision == 9,
           asset.type == nil || asset.type == .normal { return true }
        return allowLegacyJettons && !chainAsset.isNative && !asset.isNative && !asset.isUtility &&
            asset.type != .normal && asset.ethereumType == nil && asset.precision <= 255 &&
            (try? TonTransferTransactionBuilder.canonicalMainnetAddress(asset.id, basechainOnly: true)) != nil
    }

    private func resolveTransfer(
        for transfer: Transfer,
        failure: (String) -> TransferServiceError
    ) async throws -> ResolvedTransfer {
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
        guard Self.supportsAsset(transfer.chainAsset, allowLegacyJettons: wallet.legacyTonAccount != nil) else {
            throw failure("Unsupported TON asset")
        }

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("TON account address is unavailable for \(chain.chainId)")
        }
        guard let account = wallet.fetch(for: chain.accountRequest()),
              account.publicKey.count == 32
        else {
            throw failure("TON public key is unavailable for \(chain.chainId)")
        }

        if !transfer.chainAsset.isNative {
            let recipient = try TonTransferTransactionBuilder.canonicalMainnetAddress(transfer.receiver)
            let tokenWallet = try await sendService.resolveJettonWallet(
                ownerAddress: sourceAddress,
                assetAddress: asset.id,
                recipientAddress: recipient,
                amount: transfer.amount.description,
                precision: Int(asset.precision)
            )
            let details = try TonJettonTransferDetails(
                masterAddress: tokenWallet.masterAddress,
                recipientAddress: recipient,
                amount: transfer.amount.description
            )
            return ResolvedTransfer(
                publicKey: account.publicKey,
                senderAddress: sourceAddress,
                recipientAddress: tokenWallet.walletAddress,
                amountNanotons: TonJettonTransferDetails.attachedNanotons,
                bounce: true,
                jetton: details
            )
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
            bounce: bounce,
            jetton: nil
        )
    }
}

final class SolanaTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let network: UniversalWalletRegistry.SolanaNetwork
    private let rpcClient: SolanaRpcClientProtocol
    /// The node requests start at; the failover client moves down its list from here.
    private let rpcURL: String
    private let sendService: SolanaSendService
    private let balanceSync: SolanaBalanceSyncing
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private let sendGate: UniversalSendGate
    private let broadcaster: SolanaTransactionBroadcaster
    private let budgetQuotes = SolanaComputeBudgetQuoteStore()
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        rpcClient: SolanaRpcClientProtocol? = nil,
        balanceSync: SolanaBalanceSyncing? = nil,
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
        sendGate: UniversalSendGate = .production,
        pendingStore: SolanaPendingBroadcastStoring = SolanaPendingBroadcastStore.shared,
        confirmationPolicy: SolanaConfirmationPolicy = .standard,
        providerRPCURL: String? = SolanaRpcEndpoints.configuredProviderURL,
        networkDefinition: UniversalWalletRegistry.SolanaNetwork? = nil
    ) throws {
        self.wallet = wallet
        self.chain = chain
        self.sendGate = sendGate
        network = try networkDefinition ?? Self.solanaNetwork(for: chain)
        guard UniversalWalletChainAccountSupport.canonicalChainId(for: network.chainId).lowercased() ==
            UniversalWalletChainAccountSupport.canonicalChainId(for: chain.chainId).lowercased() else {
            throw TransferServiceError.transferFailed(reason: "Solana network definition does not match selected chain")
        }
        let endpoints = SolanaRpcEndpoints.endpoints(for: chain, network: network, providerURL: providerRPCURL)
        guard let primary = endpoints.first else {
            throw TransferServiceError.transferFailed(reason: "No Solana RPC node is configured for \(chain.chainId)")
        }
        rpcURL = primary
        let client = try (rpcClient ?? SolanaFailoverRpcClient(endpoints: endpoints))
            .bound(toGenesisHash: network.genesisHash)
        self.rpcClient = client
        // Balances come from the same nodes as everything else; the SORA indexer serves
        // Solana testnet only.
        let balances = balanceSync ?? SolanaRpcBalanceSync(rpcClient: client)
        self.balanceSync = balances
        self.mnemonicProvider = mnemonicProvider
        sendService = SolanaSendService(
            rpcClient: client,
            balanceProvider: SolanaTransferBalanceProvider(
                balanceSync: balances,
                network: network,
                baseURL: nil
            )
        )
        broadcaster = SolanaTransactionBroadcaster(
            rpcClient: client,
            expectedPayer: UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) ?? "",
            store: pendingStore,
            policy: confirmationPolicy
        )
    }

    /// The network fee in lamports, including the priority fee. For a token transfer to a
    /// holder without a token account it also includes the rent Solana takes to open that
    /// account, because the sender's SOL pays both.
    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        try await estimateFeeQuote(for: transfer).fee
    }

    /// The fee and, within it, the deposit that opens the recipient's token account (zero
    /// when no account is opened).
    func estimateFeeQuote(for transfer: Transfer) async throws -> (fee: BigUInt, accountCreationDeposit: BigUInt) {
        let context = try resolveContext(failure: TransferServiceError.cannotEstimateFee(reason:))
        if isNativeSolAsset(transfer.chainAsset.asset) {
            return (try await estimateNativeFee(for: transfer, context: context), .zero)
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
        let recipient = try await SolanaRecipientValidator.validateRecipientAddress(
            transfer.receiver,
            purpose: .nativeTransfer,
            rpcClient: rpcClient,
            rpcURL: rpcURL
        )
        let budget = await computeBudget(
            for: SolanaComputeBudgetQuoteKey(kind: .nativeTransfer, recipient: recipient.address, assetId: transfer.chainAsset.asset.id),
            writableAccounts: [context.sourceAddress, recipient.address]
        )
        let blockhash = try await rpcClient.latestBlockhash(commitment: .confirmed, rpcURL: rpcURL)
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: context.sourceAddress,
            recipientAddress: recipient.address,
            lamports: lamports,
            recentBlockhash: blockhash.value.blockhash,
            computeBudget: budget
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana transfer fee is unavailable")
        }

        return BigUInt(UInt64(fee))
    }

    private func estimateTokenFee(
        for transfer: Transfer,
        context: SolanaTransferContext
    ) async throws -> (fee: BigUInt, accountCreationDeposit: BigUInt) {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let recipient = try await SolanaRecipientValidator.validateRecipientAddress(
            transfer.receiver,
            purpose: .tokenTransfer,
            rpcClient: rpcClient,
            rpcURL: rpcURL
        )
        let destinationTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: recipient.address,
            mintAddress: token.mintAddress,
            tokenProgram: .splToken
        )
        let destinationTokenAccountExists = try await rpcClient.accountExists(
            address: destinationTokenAccount,
            commitment: .confirmed,
            rpcURL: rpcURL
        )
        let budget = await computeBudget(
            for: SolanaComputeBudgetQuoteKey(
                kind: destinationTokenAccountExists ? .tokenTransfer : .tokenTransferOpeningAccount,
                recipient: recipient.address,
                assetId: transfer.chainAsset.asset.id
            ),
            writableAccounts: [context.sourceAddress, token.sourceTokenAccount, destinationTokenAccount]
        )
        let blockhash = try await rpcClient.latestBlockhash(commitment: .confirmed, rpcURL: rpcURL)
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: context.sourceAddress,
            sourceTokenAccount: token.sourceTokenAccount,
            destinationTokenAccount: destinationTokenAccountExists ? destinationTokenAccount : nil,
            mintAddress: token.mintAddress,
            rawAmount: token.rawAmount,
            decimals: token.decimals,
            recentBlockhash: blockhash.value.blockhash,
            tokenProgram: .splToken,
            destinationWalletAddress: destinationTokenAccountExists ? nil : recipient.address,
            computeBudget: budget
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana token transfer fee is unavailable")
        }
        guard !destinationTokenAccountExists else {
            return (BigUInt(UInt64(fee)), .zero)
        }

        let rent = BigUInt(UInt64(try await rpcClient.minimumBalanceForRentExemption(
            dataLength: SolanaRecipientValidator.tokenAccountDataLength,
            commitment: .confirmed,
            rpcURL: rpcURL
        )))
        return (BigUInt(UInt64(fee)) + rent, rent)
    }

    func submit(transfer: Transfer) async throws -> String {
        try SolanaSendAuthorization.requireCurrent()
        // A remote veto that arrived after the fee was quoted must stop the transfer before
        // any key access, signing or broadcast.
        try sendGate.requireTransfer(on: .solana)
        let context = try resolveContext(failure: TransferServiceError.transferFailed(reason:))

        let scope = pendingScope
        guard let attempt = SolanaSubmissionRegistry.shared.begin(scope) else {
            throw TransferServiceError.transferFailed(reason: "Another Solana transfer from this wallet is still being sent")
        }
        defer { SolanaSubmissionRegistry.shared.end(attempt) }

        // Double-pay guard: while an earlier transfer could still land, nothing new is signed.
        try await requireNoTransferInFlight(scope: scope, attempt: attempt)

        try await rpcClient.verifyCluster(rpcURL: rpcURL)
        try SolanaSendAuthorization.requireCurrent()
        try requireClear(broadcaster.retainedTransferState(scope: scope))
        // The durable read can wait on storage; selection may change during that wait.
        try SolanaSendAuthorization.requireCurrent()
        guard let secret = try mnemonicProvider.secret(for: wallet, chain: chain) else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try SolanaKeyDerivation.deriveAccount(
                mnemonic: secret.mnemonic,
                passphrase: secret.passphrase
            ).address
        } catch {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is invalid")
        }

        guard derivedAddress == context.sourceAddress else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic does not match selected wallet")
        }

        let prepared: PreparedBroadcast
        do {
            if isNativeSolAsset(transfer.chainAsset.asset) {
                prepared = try await prepareNative(transfer: transfer, context: context, secret: secret)
            } else {
                prepared = try await prepareToken(transfer: transfer, context: context, secret: secret)
            }
        } catch let error as SolanaSendServiceError {
            throw Self.transferError(for: error)
        }

        let outcome = try await broadcaster.broadcast(
            prepared.signed,
            lastValidBlockHeight: prepared.lastValidBlockHeight,
            blockhashContextSlot: prepared.blockhashContextSlot,
            scope: scope,
            options: Self.broadcastOptions,
            rpcURL: rpcURL,
            attempt: attempt
        )
        return try Self.signature(from: outcome)
    }

    /// Re-sends the stored bytes of the unresolved transfer `hash`: the same signature, so it
    /// can land at most once.
    func retryUnresolvedTransfer(hash: String) async throws -> String {
        try SolanaSendAuthorization.requireCurrent()
        try sendGate.requireTransfer(on: .solana)
        let scope = pendingScope
        guard let attempt = SolanaSubmissionRegistry.shared.begin(scope) else {
            throw TransferServiceError.transferFailed(reason: "Another Solana transfer from this wallet is still being sent")
        }
        defer { SolanaSubmissionRegistry.shared.end(attempt) }

        guard let outcome = await broadcaster.retry(
            signature: hash,
            scope: scope,
            options: Self.broadcastOptions,
            rpcURL: rpcURL,
            attempt: attempt
        ) else {
            throw TransferServiceError.transferFailed(reason: "There is no unresolved Solana transfer to retry")
        }
        return try Self.signature(from: outcome)
    }

    private func requireNoTransferInFlight(
        scope: SolanaPendingBroadcastScope, attempt: SolanaSubmissionRegistry.Attempt
    ) async throws {
        if let signature = broadcaster.unavailableSignature(for: scope) {
            throw TransferServiceError.solanaRecoveryUnavailable(signature: signature)
        }
        try requireClear(await broadcaster.priorTransferState(scope: scope, rpcURL: rpcURL, attempt: attempt))
    }

    private func requireClear(_ state: SolanaPriorTransferState) throws {
        switch state {
        case .inProgress:
            throw TransferServiceError.transferFailed(
                reason: "Another Solana transfer from this wallet is still being sent"
            )
        case .clear:
            return
        case .unreadableRecord:
            throw TransferServiceError.solanaRecoveryRecordUnreadable
        case let .sentAfterAll(signature):
            throw TransferServiceError.solanaPriorTransferConfirmed(signature: signature)
        case let .notSentAfterAll(signature):
            throw TransferServiceError.solanaPriorTransferNotSent(signature: signature)
        case let .unverified(signature):
            throw TransferServiceError.solanaPriorTransferUnverified(signature: signature)
        case let .unresolved(signature):
            throw TransferServiceError.solanaPriorTransferUnresolved(signature: signature)
        }
    }

    private struct PreparedBroadcast {
        let signed: SignedSolanaTransaction
        let lastValidBlockHeight: Int64
        let blockhashContextSlot: Int64
    }

    private func prepareNative(
        transfer: Transfer,
        context: SolanaTransferContext,
        secret: UniversalWalletSecret
    ) async throws -> PreparedBroadcast {
        let lamports = try resolveLamports(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let recipient = try await SolanaRecipientValidator.validateRecipientAddress(
            transfer.receiver,
            purpose: .nativeTransfer,
            rpcClient: rpcClient,
            rpcURL: rpcURL
        )
        let rentExemptMinimum = try await rpcClient.minimumBalanceForRentExemption(
            dataLength: 0,
            commitment: .confirmed,
            rpcURL: rpcURL
        )
        let budget = await computeBudget(
            for: SolanaComputeBudgetQuoteKey(kind: .nativeTransfer, recipient: recipient.address, assetId: transfer.chainAsset.asset.id),
            writableAccounts: [context.sourceAddress, recipient.address]
        )
        let prepared = try await sendService.prepare(
            SolanaSendRequest(
                mnemonic: secret.mnemonic,
                recipientAddress: recipient.address,
                lamports: lamports,
                passphrase: secret.passphrase,
                rpcURL: rpcURL,
                computeBudget: budget,
                rentRules: SolanaRentRules(
                    rentExemptMinimumLamports: rentExemptMinimum,
                    recipientExists: recipient.account != nil
                )
            )
        )

        return PreparedBroadcast(
            signed: prepared.signed,
            lastValidBlockHeight: prepared.blockhash.value.lastValidBlockHeight,
            blockhashContextSlot: prepared.blockhash.context.slot
        )
    }

    private func prepareToken(
        transfer: Transfer,
        context: SolanaTransferContext,
        secret: UniversalWalletSecret
    ) async throws -> PreparedBroadcast {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let recipient = try await SolanaRecipientValidator.validateRecipientAddress(
            transfer.receiver,
            purpose: .tokenTransfer,
            rpcClient: rpcClient,
            rpcURL: rpcURL
        )
        let destinationTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: recipient.address,
            mintAddress: token.mintAddress,
            tokenProgram: .splToken
        )
        let destinationTokenAccountExists = try await rpcClient.accountExists(
            address: destinationTokenAccount,
            commitment: .confirmed,
            rpcURL: rpcURL
        )
        let budget = await computeBudget(
            for: SolanaComputeBudgetQuoteKey(
                kind: destinationTokenAccountExists ? .tokenTransfer : .tokenTransferOpeningAccount,
                recipient: recipient.address,
                assetId: transfer.chainAsset.asset.id
            ),
            writableAccounts: [context.sourceAddress, token.sourceTokenAccount, destinationTokenAccount]
        )
        let prepared = try await sendService.prepareTokenTransfer(
            SolanaTokenSendRequest(
                mnemonic: secret.mnemonic,
                sourceTokenAccount: token.sourceTokenAccount,
                mintAddress: token.mintAddress,
                rawAmount: token.rawAmount,
                decimals: token.decimals,
                passphrase: secret.passphrase,
                rpcURL: rpcURL,
                tokenProgram: .splToken,
                destinationWalletAddress: recipient.address,
                computeBudget: budget
            )
        )

        return PreparedBroadcast(
            signed: prepared.signed,
            lastValidBlockHeight: prepared.blockhash.value.lastValidBlockHeight,
            blockhashContextSlot: prepared.blockhash.context.slot
        )
    }

    /// The price is read from recent fees once per recipient and asset and reused for two
    /// minutes, so the transfer pays the fee the user reviewed.
    private func computeBudget(
        for key: SolanaComputeBudgetQuoteKey,
        writableAccounts: [String]
    ) async -> SolanaComputeBudget {
        if let quoted = budgetQuotes.budget(for: key) {
            return quoted
        }

        let recentFees = (try? await rpcClient.recentPrioritizationFees(accounts: writableAccounts, rpcURL: rpcURL)) ?? []
        let budget = SolanaComputeBudget(
            unitLimit: SolanaPriorityFeePolicy.unitLimit(for: key.kind),
            unitPriceMicroLamports: SolanaPriorityFeePolicy.unitPrice(recentFees: recentFees)
        )
        budgetQuotes.save(budget, for: key)
        return budget
    }

    private static let broadcastOptions = SolanaBroadcastOptions(preflightCommitment: .confirmed)

    private var pendingScope: SolanaPendingBroadcastScope {
        SolanaPendingBroadcastScope(walletId: wallet.metaId, chainId: chain.chainId)
    }

    private static func signature(from outcome: SolanaTransferOutcome) throws -> String {
        switch outcome {
        case let .sent(signature, _):
            return signature
        case let .failedOnChain(signature):
            throw TransferServiceError.solanaTransferFailed(signature: signature)
        case let .notSent(reason):
            throw TransferServiceError.solanaTransferNotSent(reason)
        case let .unknown(signature):
            throw TransferServiceError.solanaBroadcastOutcomeUnknown(signature: signature)
        case let .unverified(signature):
            throw TransferServiceError.solanaTransferUnverified(signature: signature)
        case let .recoveryUnavailable(signature):
            throw TransferServiceError.solanaRecoveryUnavailable(signature: signature)
        case .recoveryRecordUnreadable:
            throw TransferServiceError.solanaRecoveryRecordUnreadable
        }
    }

    private static func transferError(for error: SolanaSendServiceError) -> Error {
        switch error {
        case .insufficientSolBalance:
            return SolanaTransferRefusal.insufficientSol
        case .insufficientTokenBalance, .tokenBalanceMismatch:
            return SolanaTransferRefusal.insufficientTokenBalance
        case .simulationFailed:
            // Simulation runs before anything is sent; the network would refuse the same.
            return TransferServiceError.solanaTransferNotSent(.rejectedByNetwork)
        case .invalidAccount, .feeUnavailable, .broadcastSignatureMismatch, .tokenMetadataMismatch,
             .token2022TransferFeeNotAcknowledged, .token2022TransferHookAccountsMissing,
             .unsupportedToken2022Extension:
            return TransferServiceError.transferFailed(reason: "Solana transfer could not be prepared: \(error)")
        }
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let quote = try await self.estimateFeeQuote(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                if let breakdownListener = listener as? SolanaTransferFeeBreakdownListener {
                    breakdownListener.didReceiveSolanaFee(
                        fee: quote.fee,
                        accountCreationDeposit: quote.accountCreationDeposit
                    )
                } else {
                    listener?.didReceiveFee(fee: quote.fee)
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
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(failure: (String) -> TransferServiceError) throws -> SolanaTransferContext {
        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Solana account address is unavailable for \(chain.chainId)")
        }

        let normalizedSourceAddress: String
        do {
            normalizedSourceAddress = try SolanaRpcRoutes.normalizePublicKey(sourceAddress)
        } catch {
            throw failure("Solana source address is invalid")
        }

        return SolanaTransferContext(sourceAddress: normalizedSourceAddress, network: network)
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

    private func isNativeSolAsset(_ asset: AssetModel) -> Bool {
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

    /// The token account to send from: the sender's associated token account when it holds the
    /// amount, otherwise the largest account that does. The balance shown is the sum over every
    /// token account of the mint, so an amount no single account holds is refused with
    /// `tokenBalanceSplit` rather than as a missing balance.
    static func sourceTokenHolding(
        among holdings: [UniversalWalletIndexedAssetBalance],
        associatedTokenAccount: String?,
        rawAmount: BigUInt
    ) throws -> UniversalWalletIndexedAssetBalance? {
        func amount(_ holding: UniversalWalletIndexedAssetBalance) -> BigUInt {
            BigUInt(holding.amount) ?? .zero
        }

        let associated = holdings.first { $0.tokenAccountId != nil && $0.tokenAccountId == associatedTokenAccount }
        if let associated, amount(associated) >= rawAmount {
            return associated
        }
        if let covering = holdings.filter({ amount($0) >= rawAmount }).max(by: { amount($0) < amount($1) }) {
            return covering
        }

        let total = holdings.reduce(BigUInt.zero) { $0 + amount($1) }
        if holdings.count > 1, total >= rawAmount {
            throw SolanaTransferRefusal.tokenBalanceSplit
        }

        // Not enough in all accounts together: the balance check reports it.
        return associated ?? holdings.max { amount($0) < amount($1) }
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
            baseURL: nil,
            includeTokenMetadata: false
        )
        let holdings = balances.tokenBalances.filter { matchesTokenBalance($0, asset: transfer.chainAsset.asset) }
        guard !holdings.isEmpty else {
            throw failure("Solana token balance is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        let splHoldings = holdings.filter { $0.tokenProgram == Self.splTokenProgramName }
        guard !splHoldings.isEmpty else {
            throw SolanaTransferRefusal.unsupportedTokenProgram
        }

        let associated = splHoldings.first.flatMap { holding -> String? in
            guard let mint = holding.contractAddress?.nonEmpty ?? holding.assetId.nonEmpty else {
                return nil
            }
            return try? SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
                walletAddress: context.sourceAddress,
                mintAddress: mint,
                tokenProgram: .splToken
            )
        }
        let balance = try Self.sourceTokenHolding(
            among: splHoldings,
            associatedTokenAccount: associated,
            rawAmount: BigUInt(rawAmount)
        )

        guard let balance, let sourceTokenAccount = balance.tokenAccountId?.nonEmpty else {
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

    private static let splTokenProgramName = "spl-token"
}

/// How large a compute budget each kind of transfer asks for and what it bids per unit.
enum SolanaPriorityFeePolicy {
    enum TransferKind: Hashable {
        case nativeTransfer
        case tokenTransfer
        case tokenTransferOpeningAccount
    }

    /// A price that keeps the transaction in line with the cluster even when it is quiet.
    static let minimumUnitPriceMicroLamports: UInt64 = 1000
    /// Bounds the priority fee during spikes: 2,000,000 micro-lamports per unit is at most
    /// 0.0002 SOL for the largest budget below.
    static let maximumUnitPriceMicroLamports: UInt64 = 2_000_000

    /// Limits with a wide margin over what the transfers consumed on solana-test-validator 4.3
    /// (see docs/solana-send.md). A transaction that ran out would fail in simulation, before
    /// anything is sent.
    static func unitLimit(for kind: TransferKind) -> UInt32 {
        switch kind {
        case .nativeTransfer:
            return 2000
        case .tokenTransfer:
            return 40000
        case .tokenTransferOpeningAccount:
            return 100_000
        }
    }

    /// The 75th percentile of what recent transactions touching the same accounts paid,
    /// within the bounds above.
    static func unitPrice(recentFees: [Int64]) -> UInt64 {
        let sorted = recentFees.filter { $0 >= 0 }.map { UInt64($0) }.sorted()
        guard !sorted.isEmpty else {
            return minimumUnitPriceMicroLamports
        }

        let index = min(sorted.count - 1, (sorted.count * 3) / 4)
        return min(max(sorted[index], minimumUnitPriceMicroLamports), maximumUnitPriceMicroLamports)
    }
}

private struct SolanaComputeBudgetQuoteKey: Hashable {
    let kind: SolanaPriorityFeePolicy.TransferKind
    let recipient: String
    let assetId: String
}

private final class SolanaComputeBudgetQuoteStore {
    private static let maxAge: TimeInterval = 120

    private let lock = NSLock()
    private var quotes: [SolanaComputeBudgetQuoteKey: (budget: SolanaComputeBudget, quotedAt: Date)] = [:]

    func budget(for key: SolanaComputeBudgetQuoteKey) -> SolanaComputeBudget? {
        lock.lock()
        defer { lock.unlock() }
        guard let quote = quotes[key], Date().timeIntervalSince(quote.quotedAt) < Self.maxAge else {
            return nil
        }
        return quote.budget
    }

    func save(_ budget: SolanaComputeBudget, for key: SolanaComputeBudgetQuoteKey) {
        lock.lock()
        defer { lock.unlock() }
        quotes[key] = (budget, Date())
    }
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
    /// The wallet password when the Taira account is the one it protects.
    var passphrase: String = ""
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

        guard let secret = try mnemonicProvider.secret(for: wallet, chain: chain) else {
            throw failure("Iroha mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try IrohaKeyDerivation.deriveAddress(
                mnemonic: secret.mnemonic,
                passphrase: secret.passphrase,
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
                mnemonicOrSeed: secret.mnemonic,
                passphrase: secret.passphrase,
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
        if network == UniversalWalletRegistry.taira,
           let url = network.toriiBaseURL?.absoluteString.nonEmpty {
            return url
        }

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
