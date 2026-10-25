import Foundation

protocol BitcoinIndexerClientProtocol {
    func address(address: String, network: BitcoinIndexerNetwork, baseURL: String?) async throws -> BitcoinEsploraAddress
    func utxos(address: String, network: BitcoinIndexerNetwork, baseURL: String?) async throws -> [BitcoinEsploraUtxo]
    func transactions(
        address: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?,
        lastSeenTxid: String?,
        mempool: Bool
    ) async throws -> [BitcoinEsploraTransaction]
    func feeEstimates(network: BitcoinIndexerNetwork, baseURL: String?) async throws -> [String: Double]
    func broadcastTransaction(txHex: String, network: BitcoinIndexerNetwork, baseURL: String?) async throws -> String
    /// The status of a transaction the indexer knows, in the mempool or in a block; `nil` when
    /// the indexer answers that it has never seen it.
    func transactionStatus(
        txid: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraTxStatus?
    func outspend(
        txid: String,
        vout: Int64,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraOutspend
}

enum BitcoinIndexerClientError: Error, Equatable {
    /// The client cannot look transactions up, so a broadcast it could not confirm stays unknown.
    case transactionLookupUnavailable
    /// Every Esplora service asked the app to slow down; nothing was requested.
    case rateLimited(retryAfter: TimeInterval)
    /// A transaction lookup answered with a different transaction.
    case unexpectedTransaction
}

extension BitcoinIndexerClientProtocol {
    func transactionStatus(
        txid _: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> BitcoinEsploraTxStatus? {
        throw BitcoinIndexerClientError.transactionLookupUnavailable
    }

    func outspend(
        txid _: String,
        vout _: Int64,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> BitcoinEsploraOutspend {
        throw BitcoinIndexerClientError.transactionLookupUnavailable
    }
}

final class BitcoinIndexerClient: BitcoinIndexerClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let decoder: JSONDecoder

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.transport = transport
        self.decoder = decoder
    }

    func address(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinEsploraAddress {
        try await get(try BitcoinIndexerRoutes.addressURL(address: address, network: network, baseURL: baseURL))
    }

    func utxos(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> [BitcoinEsploraUtxo] {
        try await get(try BitcoinIndexerRoutes.utxosURL(address: address, network: network, baseURL: baseURL))
    }

    func transactions(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil,
        lastSeenTxid: String? = nil,
        mempool: Bool = false
    ) async throws -> [BitcoinEsploraTransaction] {
        try await get(
            try BitcoinIndexerRoutes.transactionsURL(
                address: address,
                network: network,
                baseURL: baseURL,
                lastSeenTxid: lastSeenTxid,
                mempool: mempool
            )
        )
    }

    func feeEstimates(
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> [String: Double] {
        try await get(try BitcoinIndexerRoutes.feeEstimatesURL(network: network, baseURL: baseURL))
    }

    func broadcastTransaction(
        txHex: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> String {
        let normalizedHex = try BitcoinIndexerRoutes.normalizeBroadcastTransactionBody(txHex)
        var request = urlRequest(
            url: try BitcoinIndexerRoutes.broadcastTransactionURL(network: network, baseURL: baseURL),
            method: "POST"
        )
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(normalizedHex.utf8)

        return String(decoding: try await transport.perform(request), as: UTF8.self)
    }

    func transactionStatus(
        txid: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinEsploraTxStatus? {
        struct KnownTransaction: Decodable {
            let txid: String
            let status: BitcoinEsploraTxStatus
        }

        let expectedTxid = try BitcoinIndexerRoutes.normalizeTxid(txid)
        let transaction: KnownTransaction
        do {
            transaction = try await get(
                try BitcoinIndexerRoutes.transactionURL(txid: expectedTxid, network: network, baseURL: baseURL)
            )
        } catch UniversalWalletHTTPTransportError.httpStatusCode(404, _) {
            return nil
        }
        // A reply about some other transaction proves nothing about this one.
        guard transaction.txid.lowercased() == expectedTxid else {
            throw BitcoinIndexerClientError.unexpectedTransaction
        }

        return transaction.status
    }

    func outspend(
        txid: String,
        vout: Int64,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) async throws -> BitcoinEsploraOutspend {
        try await get(
            try BitcoinIndexerRoutes.outspendURL(txid: txid, vout: vout, network: network, baseURL: baseURL)
        )
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decoder.decode(T.self, from: try await transport.perform(urlRequest(url: url)))
    }

    private func urlRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }
}

typealias BitcoinIndexerEndpointHealth = UniversalWalletEndpointHealth

/// Remembers which public services (Esplora indexers, Solana RPC nodes) recently failed or
/// asked the app to slow down, so the next request goes to a healthy one first instead of
/// hammering a service that said no.
final class UniversalWalletEndpointHealth {
    /// The Bitcoin indexers' record.
    static let shared = UniversalWalletEndpointHealth()
    /// The Solana RPC nodes' record, kept apart from Bitcoin's.
    static let solanaRpc = UniversalWalletEndpointHealth()
    static let initialBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 15 * 60

    private struct State {
        var consecutiveFailures = 0
        var retryAt = Date.distantPast
    }

    private let lock = NSLock()
    private let now: () -> Date
    private var states: [String: State] = [:]

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Services that may be asked now, in the given order.
    func available(_ endpoints: [String]) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let date = now()
        return endpoints.filter { (states[$0]?.retryAt ?? .distantPast) <= date }
    }

    /// Seconds until the first of the given services may be asked again; zero if one may now.
    func retryDelay(for endpoints: [String]) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        let date = now()
        let delays = endpoints.map { max(0, (states[$0]?.retryAt ?? .distantPast).timeIntervalSince(date)) }
        return delays.min() ?? 0
    }

    func markSuccess(_ endpoint: String) {
        lock.lock()
        defer { lock.unlock() }
        states[endpoint] = nil
    }

    /// Backs off exponentially from 30 seconds to 15 minutes, or for the service's own
    /// `Retry-After` when that is longer.
    func markFailure(_ endpoint: String, retryAfter: TimeInterval? = nil) {
        lock.lock()
        defer { lock.unlock() }
        var state = states[endpoint] ?? State()
        state.consecutiveFailures += 1
        let exponent = Double(min(state.consecutiveFailures - 1, 10))
        let backoff = min(Self.initialBackoff * pow(2, exponent), Self.maxBackoff)
        let delay = min(max(backoff, retryAfter ?? 0), Self.maxBackoff)
        state.retryAt = now().addingTimeInterval(delay)
        states[endpoint] = state
    }
}

/// Sends each request to the preferred Esplora service and, when that one is unreachable,
/// failing or rate limiting, to the next (mempool.space, then blockstream.info). A caller that
/// names a base URL outside the network's own list is talking to a specific service and gets
/// no failover.
final class BitcoinFailoverIndexerClient: BitcoinIndexerClientProtocol {
    private let client: BitcoinIndexerClientProtocol
    private let health: BitcoinIndexerEndpointHealth
    private let endpoints: (BitcoinIndexerNetwork) -> [String]

    init(
        client: BitcoinIndexerClientProtocol = BitcoinIndexerClient(),
        health: BitcoinIndexerEndpointHealth = .shared,
        endpoints: @escaping (BitcoinIndexerNetwork) -> [String] = { $0.baseURLs.map(\.absoluteString) }
    ) {
        self.client = client
        self.health = health
        self.endpoints = endpoints
    }

    func address(
        address: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraAddress {
        try await read(network: network, baseURL: baseURL) {
            try await self.client.address(address: address, network: network, baseURL: $0)
        }
    }

    func utxos(
        address: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> [BitcoinEsploraUtxo] {
        try await read(network: network, baseURL: baseURL) {
            try await self.client.utxos(address: address, network: network, baseURL: $0)
        }
    }

    func transactions(
        address: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?,
        lastSeenTxid: String?,
        mempool: Bool
    ) async throws -> [BitcoinEsploraTransaction] {
        try await read(network: network, baseURL: baseURL) {
            try await self.client.transactions(
                address: address,
                network: network,
                baseURL: $0,
                lastSeenTxid: lastSeenTxid,
                mempool: mempool
            )
        }
    }

    func feeEstimates(network: BitcoinIndexerNetwork, baseURL: String?) async throws -> [String: Double] {
        try await read(network: network, baseURL: baseURL) {
            try await self.client.feeEstimates(network: network, baseURL: $0)
        }
    }

    func outspend(
        txid: String,
        vout: Int64,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraOutspend {
        // Resolving a transfer whose outcome is unknown is rare and must not be starved by a
        // balance refresh that was rate limited a moment ago.
        try await read(network: network, baseURL: baseURL, honoursBackoff: false) {
            try await self.client.outspend(txid: txid, vout: vout, network: network, baseURL: $0)
        }
    }

    /// Asks every service: the transaction counts as seen as soon as one of them has it, and
    /// as unseen only when at least one answered and none has it.
    func transactionStatus(
        txid: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraTxStatus? {
        var answered = false
        var lastError: Error?

        for endpoint in candidates(network: network, baseURL: baseURL) {
            do {
                if let status = try await client.transactionStatus(txid: txid, network: network, baseURL: endpoint) {
                    return status
                }
                answered = true
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        if answered {
            return nil
        }
        throw lastError ?? BitcoinIndexerClientError.transactionLookupUnavailable
    }

    /// Offers the same signed transaction to each service until one accepts it. The bytes are
    /// identical every time, so a second service can only confirm or refuse the same payment.
    func broadcastTransaction(
        txHex: String,
        network: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> String {
        var attempts: [BitcoinBroadcastAttemptOutcome] = []

        for endpoint in candidates(network: network, baseURL: baseURL) {
            do {
                let txid = try await client.broadcastTransaction(txHex: txHex, network: network, baseURL: endpoint)
                health.markSuccess(endpoint)
                return txid
            } catch {
                attempts.append(BitcoinBroadcastAttemptOutcome(error: error))
            }
        }

        throw BitcoinBroadcastFailure(attempts: attempts)
    }

    private func candidates(network: BitcoinIndexerNetwork, baseURL: String?) -> [String] {
        let known = endpoints(network)
        guard let baseURL else {
            return known
        }
        let normalized = Self.normalized(baseURL)
        return known.contains { Self.normalized($0) == normalized } ? known : [baseURL]
    }

    private func read<T>(
        network: BitcoinIndexerNetwork,
        baseURL: String?,
        honoursBackoff: Bool = true,
        _ request: (String) async throws -> T
    ) async throws -> T {
        let candidates = candidates(network: network, baseURL: baseURL)
        let available = honoursBackoff ? health.available(candidates) : candidates
        guard !available.isEmpty else {
            throw BitcoinIndexerClientError.rateLimited(retryAfter: health.retryDelay(for: candidates))
        }

        var lastError: Error?
        for endpoint in available {
            do {
                let value = try await request(endpoint)
                health.markSuccess(endpoint)
                return value
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                switch EndpointVerdict(error) {
                case .requestRefused:
                    // The service answered and refused this request (bad address, unknown
                    // transaction): another service would say the same.
                    throw error
                case let .serviceBusy(retryAfter):
                    health.markFailure(endpoint, retryAfter: retryAfter)
                case .unreachable:
                    break
                }
                lastError = error
            }
        }

        throw lastError ?? BitcoinIndexerClientError.rateLimited(retryAfter: health.retryDelay(for: candidates))
    }

    private enum EndpointVerdict {
        /// The request itself is wrong; no other service would accept it.
        case requestRefused
        /// The service is rate limiting or failing: leave it alone for a while.
        case serviceBusy(retryAfter: TimeInterval?)
        /// Nothing came back (offline, timeout, TLS, a body that is not Esplora JSON). The next
        /// service is tried, but this one is not held back: being offline is not its fault,
        /// and the next refresh after reconnecting should reach it straight away.
        case unreachable

        init(_ error: Error) {
            switch error {
            case let UniversalWalletHTTPTransportError.rateLimited(_, retryAfter):
                self = .serviceBusy(retryAfter: retryAfter)
            case let UniversalWalletHTTPTransportError.httpStatusCode(status, _):
                self = status == 408 || status >= 500 ? .serviceBusy(retryAfter: nil) : .requestRefused
            case is BitcoinIndexerRouteError:
                self = .requestRefused
            default:
                self = .unreachable
            }
        }
    }

    private static func normalized(_ baseURL: String) -> String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}
