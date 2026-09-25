import Foundation

final class BitcoinSendService {
    private let planner: BitcoinSendPlanner
    private let broadcaster: BitcoinTransactionBroadcaster

    init(
        planner: BitcoinSendPlanner,
        broadcaster: BitcoinTransactionBroadcaster
    ) {
        self.planner = planner
        self.broadcaster = broadcaster
    }

    convenience init(client: BitcoinIndexerClientProtocol) {
        self.init(
            planner: BitcoinSendPlanner(client: client),
            broadcaster: BitcoinTransactionBroadcaster(client: client)
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

    func send(_ request: BitcoinSendRequest) async throws -> BitcoinSentTransaction {
        let prepared = try await prepare(request)
        let broadcast = try await broadcaster.broadcast(
            txHex: prepared.transaction.txHex,
            network: request.network,
            baseURL: request.baseURL
        )

        guard broadcast.txid == prepared.transaction.txid else {
            throw BitcoinSendServiceError.broadcastTxidMismatch
        }

        return BitcoinSentTransaction(
            broadcastTxid: broadcast.txid,
            prepared: prepared
        )
    }
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
    case broadcastTxidMismatch
    case feeQuoteMismatch
    case plannedTransactionMismatch
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
