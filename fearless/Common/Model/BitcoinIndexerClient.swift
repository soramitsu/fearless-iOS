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

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decoder.decode(T.self, from: try await transport.perform(urlRequest(url: url)))
    }

    private func urlRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }
}
