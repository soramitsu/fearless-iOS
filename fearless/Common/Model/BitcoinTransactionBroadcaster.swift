import Foundation

final class BitcoinTransactionBroadcaster {
    private let client: BitcoinIndexerClientProtocol

    init(client: BitcoinIndexerClientProtocol) {
        self.client = client
    }

    func broadcast(
        txHex: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinBroadcastResult {
        let normalizedTxHex: String
        do {
            normalizedTxHex = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody(txHex)
        } catch {
            throw BitcoinBroadcastError.invalidTxHex
        }

        let txid = try await client.broadcastTransaction(
            txHex: normalizedTxHex,
            network: network,
            baseURL: baseURL
        )
        let normalizedTxid: String
        do {
            normalizedTxid = try BitcoinIndexerRoutes.normalizeTxid(txid)
        } catch {
            throw BitcoinBroadcastError.invalidTxidResponse
        }

        return BitcoinBroadcastResult(
            network: network,
            txHex: normalizedTxHex,
            txid: normalizedTxid
        )
    }
}

struct BitcoinBroadcastResult: Equatable {
    let network: BitcoinIndexerNetwork
    let txHex: String
    let txid: String
}

enum BitcoinBroadcastError: Error, Equatable {
    case invalidTxHex
    case invalidTxidResponse
}

/// How one failed broadcast attempt ended, judged only by whether the signed transaction can
/// have reached a Bitcoin node. Anything not provably undelivered is ambiguous: the wallet
/// must then find out what happened before it may build another payment.
enum BitcoinBroadcastAttemptOutcome: Equatable {
    /// The request never reached a node: no connection was made, or the service turned the
    /// request away before handling it.
    case notSent
    /// A node answered and refused the transaction, with its reason.
    case rejected(String)
    /// The node may have accepted the transaction (timeout, dropped connection, server error,
    /// unreadable reply).
    case ambiguous

    init(error: Error) {
        switch error {
        case BitcoinBroadcastError.invalidTxHex, is BitcoinIndexerRouteError:
            self = .notSent
        case BitcoinBroadcastError.invalidTxidResponse:
            self = .ambiguous
        case let UniversalWalletHTTPTransportError.rateLimited(statusCode, _):
            // 429 is the edge refusing to forward the request; 503 can come from behind it.
            self = statusCode == 429 ? .notSent : .ambiguous
        case let UniversalWalletHTTPTransportError.httpStatusCode(statusCode, body):
            let reason = Self.rejectionReason(from: body)
            if (400 ... 499).contains(statusCode), statusCode != 408, !Self.nodeAlreadyHasIt(reason) {
                self = .rejected(reason)
            } else {
                self = .ambiguous
            }
        case let urlError as URLError:
            self = Self.neverConnectedCodes.contains(urlError.code) ? .notSent : .ambiguous
        default:
            self = .ambiguous
        }
    }

    /// Failures that happen before a connection carries the request body.
    private static let neverConnectedCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .secureConnectionFailed,
        .serverCertificateUntrusted,
        .serverCertificateHasBadDate,
        .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid,
        .clientCertificateRejected,
        .clientCertificateRequired,
        .appTransportSecurityRequiresSecureConnection,
        .dataNotAllowed,
        .internationalRoamingOff,
        .unsupportedURL,
        .badURL
    ]

    /// Bitcoin Core's refusals for a transaction it already holds ("txn-already-in-mempool",
    /// "txn-already-known", "Transaction already in block chain", "Transaction outputs already
    /// in utxo set", "txn-same-nonwitness-data-in-mempool"). They fail the request although
    /// the payment is out, so they are never read as "nothing was sent".
    private static func nodeAlreadyHasIt(_ reason: String) -> Bool {
        let text = reason.lowercased()
        return text.contains("already") || text.contains("same-nonwitness-data-in-mempool")
    }

    private static func rejectionReason(from body: Data) -> String {
        let text = String(decoding: body.prefix(512), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "rejected" : text
    }
}

/// Every Esplora service that was offered a transaction failed to confirm it took it.
struct BitcoinBroadcastFailure: Error, Equatable {
    let attempts: [BitcoinBroadcastAttemptOutcome]

    init(attempts: [BitcoinBroadcastAttemptOutcome]) {
        self.attempts = attempts
    }

    init(error: Error) {
        if let failure = error as? BitcoinBroadcastFailure {
            self = failure
        } else {
            attempts = [BitcoinBroadcastAttemptOutcome(error: error)]
        }
    }

    /// No attempt can have delivered the transaction to a node.
    var isDefinitelyNotSent: Bool {
        attempts.allSatisfy { $0 == .notSent }
    }

    /// At least one node may hold the transaction without the wallet knowing.
    var mayHaveReachedNetwork: Bool {
        attempts.contains(.ambiguous)
    }

    var rejectionReason: String? {
        attempts.lazy.compactMap { attempt -> String? in
            if case let .rejected(reason) = attempt {
                return reason
            }
            return nil
        }.first
    }
}
