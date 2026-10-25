import Foundation

protocol SolanaIndexerClientProtocol {
    func serviceInfo(baseURL: String?) async throws -> SolanaIndexerServiceInfo
    func verifyServiceInfo(baseURL: String?, expectedChainId: String) async throws -> SolanaIndexerServiceInfo
    func balances(wallet: String, baseURL: String?) async throws -> SolanaWalletBalancesResponse
    func assets(wallet: String, baseURL: String?) async throws -> SolanaWalletAssetsResponse
    func state(wallet: String, baseURL: String?) async throws -> SolanaWalletStateResponse
    func transactions(wallet: String, baseURL: String?, before: String?, limit: Int) async throws -> SolanaWalletTransactionsResponse
    func tokenMetadata(mint: String, baseURL: String?) async throws -> SolanaTokenMetadata
    func tokenMetadataBatch(mints: [String], baseURL: String?) async throws -> SolanaTokenMetadataBatchResponse
}

extension SolanaIndexerClientProtocol {
    func verifyServiceInfo(baseURL: String?) async throws -> SolanaIndexerServiceInfo {
        try await verifyServiceInfo(
            baseURL: baseURL,
            expectedChainId: UniversalWalletRegistry.solanaMainnet.chainId
        )
    }
}

enum SolanaIndexerClientError: Error, Equatable {
    case unexpectedServiceInfo(SolanaIndexerServiceInfo)
}

final class SolanaIndexerClient: SolanaIndexerClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let defaultBaseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        defaultBaseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.transport = transport
        self.defaultBaseURL = defaultBaseURL
        self.decoder = decoder
        self.encoder = encoder
    }

    func serviceInfo(baseURL: String? = nil) async throws -> SolanaIndexerServiceInfo {
        try await get(try SolanaIndexerRoutes.serviceInfoURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func verifyServiceInfo(
        baseURL: String? = nil,
        expectedChainId: String = UniversalWalletRegistry.solanaMainnet.chainId
    ) async throws -> SolanaIndexerServiceInfo {
        let info = try await serviceInfo(baseURL: baseURL)
        guard info.isExpectedSIServiceInfo(expectedChainId: expectedChainId) else {
            throw SolanaIndexerClientError.unexpectedServiceInfo(info)
        }
        return info
    }

    func balances(wallet: String, baseURL: String? = nil) async throws -> SolanaWalletBalancesResponse {
        try await get(try SolanaIndexerRoutes.balancesURL(wallet: wallet, baseURL: resolvedBaseURL(baseURL)))
    }

    func assets(wallet: String, baseURL: String? = nil) async throws -> SolanaWalletAssetsResponse {
        try await get(try SolanaIndexerRoutes.assetsURL(wallet: wallet, baseURL: resolvedBaseURL(baseURL)))
    }

    func state(wallet: String, baseURL: String? = nil) async throws -> SolanaWalletStateResponse {
        try await get(try SolanaIndexerRoutes.stateURL(wallet: wallet, baseURL: resolvedBaseURL(baseURL)))
    }

    func transactions(
        wallet: String,
        baseURL: String? = nil,
        before: String? = nil,
        limit: Int = SolanaIndexerRoutes.defaultLimit
    ) async throws -> SolanaWalletTransactionsResponse {
        try await get(
            try SolanaIndexerRoutes.transactionsURL(
                wallet: wallet,
                baseURL: resolvedBaseURL(baseURL),
                before: before,
                limit: limit
            )
        )
    }

    func tokenMetadata(mint: String, baseURL: String? = nil) async throws -> SolanaTokenMetadata {
        try await get(try SolanaIndexerRoutes.tokenMetadataURL(mint: mint, baseURL: resolvedBaseURL(baseURL)))
    }

    func tokenMetadataBatch(
        mints: [String],
        baseURL: String? = nil
    ) async throws -> SolanaTokenMetadataBatchResponse {
        let body = try SolanaIndexerRoutes.tokenMetadataBatchRequest(mints: mints)
        var request = urlRequest(
            url: try SolanaIndexerRoutes.tokenMetadataBatchURL(baseURL: resolvedBaseURL(baseURL)),
            method: "POST"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        return try decode(try await transport.perform(request))
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decode(try await transport.perform(urlRequest(url: url)))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }

    private func urlRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func resolvedBaseURL(_ baseURL: String?) -> String {
        baseURL ?? defaultBaseURL
    }
}
