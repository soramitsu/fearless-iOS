import Foundation

final class BitcoinSendService {
    /// How often a transaction that may have been accepted is looked up before the wallet
    /// reports that it does not know what happened. Indexers list a mempool transaction a
    /// moment after their node accepts it.
    struct StatusPolling: Equatable {
        let attempts: Int
        let interval: TimeInterval

        static let standard = StatusPolling(attempts: 3, interval: 2)
        static let once = StatusPolling(attempts: 1, interval: 0)
    }

    private let planner: BitcoinSendPlanner
    private let broadcaster: BitcoinTransactionBroadcaster
    private let client: BitcoinIndexerClientProtocol
    private let resolver: BitcoinPendingBroadcastResolver
    private let pendingStore: BitcoinPendingBroadcastStoring
    private let statusPolling: StatusPolling
    private let now: () -> Date

    init(
        planner: BitcoinSendPlanner,
        broadcaster: BitcoinTransactionBroadcaster,
        client: BitcoinIndexerClientProtocol,
        pendingStore: BitcoinPendingBroadcastStoring = BitcoinPendingBroadcastStore.shared,
        statusPolling: StatusPolling = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.planner = planner
        self.broadcaster = broadcaster
        self.client = client
        resolver = BitcoinPendingBroadcastResolver(client: client)
        self.pendingStore = pendingStore
        self.statusPolling = statusPolling
        self.now = now
    }

    convenience init(
        client: BitcoinIndexerClientProtocol,
        pendingStore: BitcoinPendingBroadcastStoring = BitcoinPendingBroadcastStore.shared,
        statusPolling: StatusPolling = .standard
    ) {
        self.init(
            planner: BitcoinSendPlanner(client: client),
            broadcaster: BitcoinTransactionBroadcaster(client: client),
            client: client,
            pendingStore: pendingStore,
            statusPolling: statusPolling
        )
    }

    func prepare(_ request: BitcoinSendRequest) async throws -> BitcoinPreparedSendTransaction {
        let plan = try await planner.plan(
            amountSats: request.amountSats,
            sources: request.sources,
            recipientAddress: request.recipientAddress,
            changeAddress: request.changeAddress,
            feeRateSatPerVbyte: request.feeRateSatPerVbyte,
            feeTargetBlocks: request.feeTargetBlocks,
            includeUnconfirmed: request.includeUnconfirmed,
            maxInputs: request.maxInputs,
            requiredOutpoints: request.requiredOutpoints,
            network: request.network,
            baseURL: request.baseURL
        )
        if let expectedFeeSats = request.expectedFeeSats,
           plan.feeSats != expectedFeeSats {
            throw BitcoinSendServiceError.feeQuoteMismatch
        }
        let transaction = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
            mnemonic: request.mnemonic,
            passphrase: request.passphrase,
            inputs: plan.selectedUtxos,
            outputs: [BitcoinPaymentOutput(address: plan.recipientAddress, valueSats: plan.amountSats)],
            changeAddress: plan.changeAddress,
            feeSats: plan.feeSats,
            network: request.network.keyDerivationNetwork
        )

        guard transaction.feeSats == plan.feeSats, transaction.changeSats == plan.changeSats else {
            throw BitcoinSendServiceError.plannedTransactionMismatch
        }

        return BitcoinPreparedSendTransaction(
            plan: plan,
            transaction: transaction
        )
    }

    /// Signs and broadcasts one payment. With a `scope` the signed transaction is recorded
    /// before it leaves the device, so that whatever happens next (a timeout, a crash, a lost
    /// reply) the wallet still knows a payment may be in flight and never builds a second one
    /// from other coins. `replacing` is the unresolved transfer this payment supersedes; the
    /// request must then require that transfer's inputs.
    func send(
        _ request: BitcoinSendRequest,
        scope: BitcoinPendingBroadcastScope? = nil,
        replacing: BitcoinPendingBroadcast? = nil
    ) async throws -> BitcoinSentTransaction {
        let prepared = try await prepare(request)
        if let replacing {
            let spent = Set(prepared.plan.selectedUtxos.map(\.outpoint))
            guard replacing.inputs.allSatisfy({ spent.contains($0.outpoint.normalized) }) else {
                throw BitcoinSendServiceError.replacementDoesNotConflict
            }
        }

        if let scope {
            let record = BitcoinPendingBroadcast(
                walletId: scope.walletId,
                chainId: scope.chainId,
                txid: prepared.transaction.txid,
                txHex: prepared.transaction.txHex,
                amountSats: prepared.plan.amountSats,
                feeSats: prepared.plan.feeSats,
                recipientAddress: prepared.plan.recipientAddress,
                inputs: prepared.plan.selectedUtxos.map {
                    BitcoinPendingBroadcast.Input(txid: $0.txid, vout: $0.vout, valueSats: $0.valueSats)
                },
                createdAt: now(),
                replaced: replacing?.replacementLineage ?? []
            )
            do {
                try pendingStore.save(record, for: scope)
            } catch {
                throw BitcoinSendServiceError.pendingBroadcastNotRecorded
            }
        }

        do {
            try await deliver(
                txHex: prepared.transaction.txHex,
                txid: prepared.transaction.txid,
                network: request.network,
                baseURL: request.baseURL
            )
        } catch let error as BitcoinSendServiceError {
            switch error {
            case .broadcastNotSent, .broadcastRejected:
                // No node has this transaction and nobody else holds it: it cannot land.
                restore(replacing, clearing: prepared.transaction.txid, scope: scope)
            default:
                break
            }
            throw error
        }

        if let scope {
            pendingStore.clear(txid: prepared.transaction.txid, for: scope)
        }
        return BitcoinSentTransaction(
            broadcastTxid: prepared.transaction.txid,
            prepared: prepared
        )
    }

    /// Looks up the transfer recorded for `scope`, if any, and forgets it once the indexers
    /// prove what became of it. Builds and signs nothing.
    func checkPending(
        scope: BitcoinPendingBroadcastScope,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async -> BitcoinPendingBroadcastCheck {
        guard let record = pendingStore.pending(for: scope) else {
            return .none
        }

        switch await resolver.status(of: record, network: network, baseURL: baseURL) {
        case .seen:
            pendingStore.clear(txid: record.txid, for: scope)
            return .sent(txid: record.txid)
        case let .replacedTransferSeen(txid):
            pendingStore.clear(txid: record.txid, for: scope)
            return .sent(txid: txid)
        case .dead:
            pendingStore.clear(txid: record.txid, for: scope)
            return .none
        case .unknown:
            return .unresolved(record)
        }
    }

    /// Offers the recorded transaction to the network again. The bytes are the ones signed the
    /// first time, so however often this runs it is the same payment and can be confirmed once.
    func rebroadcast(
        _ record: BitcoinPendingBroadcast,
        scope: BitcoinPendingBroadcastScope,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> String {
        do {
            try await deliver(txHex: record.txHex, txid: record.txid, network: network, baseURL: baseURL)
            pendingStore.clear(txid: record.txid, for: scope)
            return record.txid
        } catch is BitcoinSendServiceError {
            // A refusal now says nothing about the earlier attempt; only the chain does.
            switch await resolver.status(of: record, network: network, baseURL: baseURL) {
            case .seen:
                pendingStore.clear(txid: record.txid, for: scope)
                return record.txid
            case let .replacedTransferSeen(txid):
                pendingStore.clear(txid: record.txid, for: scope)
                throw BitcoinSendServiceError.replacedTransferSent(txid: txid)
            case .dead:
                pendingStore.clear(txid: record.txid, for: scope)
                throw BitcoinSendServiceError.pendingTransferCannotConfirm(txid: record.txid)
            case .unknown:
                throw BitcoinSendServiceError.broadcastOutcomeUnknown(txid: record.txid)
            }
        }
    }

    /// Returns once a node is known to hold the transaction. Throws `broadcastNotSent` or
    /// `broadcastRejected` only when no node can hold it, and `broadcastOutcomeUnknown` for
    /// everything in between.
    private func deliver(
        txHex: String,
        txid: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws {
        let failure: BitcoinBroadcastFailure
        do {
            let broadcast = try await broadcaster.broadcast(txHex: txHex, network: network, baseURL: baseURL)
            if broadcast.txid == txid {
                return
            }
            // A node took something but names it differently: treat it as possibly sent.
            failure = BitcoinBroadcastFailure(attempts: [.ambiguous])
        } catch {
            failure = BitcoinBroadcastFailure(error: error)
        }

        if failure.isDefinitelyNotSent {
            throw BitcoinSendServiceError.broadcastNotSent
        }

        // "Already in mempool", a timeout after the node accepted it, a gateway error on the
        // way back: all of these fail the request although the payment went out.
        let lookups = failure.mayHaveReachedNetwork ? max(1, statusPolling.attempts) : 1
        for attempt in 0 ..< lookups {
            if attempt > 0, statusPolling.interval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(statusPolling.interval * 1_000_000_000))
            }
            if (try? await client.transactionStatus(txid: txid, network: network, baseURL: baseURL)) != nil {
                return
            }
        }

        if !failure.mayHaveReachedNetwork, let reason = failure.rejectionReason {
            throw BitcoinSendServiceError.broadcastRejected(reason: reason)
        }
        throw BitcoinSendServiceError.broadcastOutcomeUnknown(txid: txid)
    }

    /// A replacement that provably never left the device leaves the transfer it was meant to
    /// replace exactly as unresolved as before.
    private func restore(
        _ replacing: BitcoinPendingBroadcast?,
        clearing txid: String,
        scope: BitcoinPendingBroadcastScope?
    ) {
        guard let scope else {
            return
        }
        if let replacing {
            try? pendingStore.save(replacing, for: scope)
        } else {
            pendingStore.clear(txid: txid, for: scope)
        }
    }
}

enum BitcoinPendingBroadcastCheck: Equatable {
    /// Nothing is in flight.
    case none
    /// An earlier transfer reached the network; it is no longer tracked.
    case sent(txid: String)
    /// An earlier transfer may still be in flight.
    case unresolved(BitcoinPendingBroadcast)
}

struct BitcoinSendRequest: Equatable {
    let mnemonic: String
    let amountSats: Int64
    let sources: [BitcoinUtxoSource]
    let recipientAddress: String
    let passphrase: String
    let changeAddress: String?
    let feeRateSatPerVbyte: Double?
    let expectedFeeSats: Int64?
    let feeTargetBlocks: Int
    let includeUnconfirmed: Bool
    let maxInputs: Int
    /// Coins the transaction must spend (the inputs of an unresolved transfer it replaces).
    let requiredOutpoints: [BitcoinOutpoint]
    let network: BitcoinIndexerNetwork
    let baseURL: String?

    init(
        mnemonic: String,
        amountSats: Int64,
        sources: [BitcoinUtxoSource],
        recipientAddress: String,
        passphrase: String = "",
        changeAddress: String? = nil,
        feeRateSatPerVbyte: Double? = nil,
        expectedFeeSats: Int64? = nil,
        feeTargetBlocks: Int = BitcoinFeeEstimator.defaultTargetBlocks,
        includeUnconfirmed: Bool = false,
        maxInputs: Int = BitcoinUtxoSelector.defaultMaxInputs,
        requiredOutpoints: [BitcoinOutpoint] = [],
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) {
        self.mnemonic = mnemonic
        self.amountSats = amountSats
        self.sources = sources
        self.recipientAddress = recipientAddress
        self.passphrase = passphrase
        self.changeAddress = changeAddress
        self.feeRateSatPerVbyte = feeRateSatPerVbyte
        self.expectedFeeSats = expectedFeeSats
        self.feeTargetBlocks = feeTargetBlocks
        self.includeUnconfirmed = includeUnconfirmed
        self.maxInputs = maxInputs
        self.requiredOutpoints = requiredOutpoints
        self.network = network
        self.baseURL = baseURL
    }
}

struct BitcoinPreparedSendTransaction: Equatable {
    let plan: BitcoinSendPlan
    let transaction: BitcoinBuiltTransaction
}

struct BitcoinSentTransaction: Equatable {
    let broadcastTxid: String
    let prepared: BitcoinPreparedSendTransaction
}

enum BitcoinSendServiceError: Error, Equatable {
    /// The request never reached a node. Nothing was sent.
    case broadcastNotSent
    /// The network may have accepted the transaction; the wallet could not find out.
    case broadcastOutcomeUnknown(txid: String)
    /// A node refused the transaction and no node holds it. Nothing was sent.
    case broadcastRejected(reason: String)
    case feeQuoteMismatch
    /// The signed transaction could not be recorded, so it was not broadcast.
    case pendingBroadcastNotRecorded
    /// The recorded transfer lost its coins to another confirmed transaction.
    case pendingTransferCannotConfirm(txid: String)
    case plannedTransactionMismatch
    /// The transfer the recorded one was meant to replace is the one that was sent.
    case replacedTransferSent(txid: String)
    /// A replacement must spend the coins of the transfer it replaces.
    case replacementDoesNotConflict
}

private extension BitcoinIndexerNetwork {
    var keyDerivationNetwork: BitcoinKeyDerivation.Network {
        switch self {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
}
