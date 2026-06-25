import Foundation

protocol IrohaToriiClientProtocol {
    func health(baseURL: String?) async throws -> Data
    func accounts(baseURL: String?, limit: Int?, offset: Int64?, countMode: IrohaToriiCountMode?) async throws -> IrohaAccountListResponse
    func account(accountID: String, baseURL: String?, network: UniversalWalletRegistry.IrohaNetwork) async throws -> IrohaAccountListItem
    func accountAssets(
        accountID: String,
        baseURL: String?,
        limit: Int?,
        offset: Int64?,
        countMode: IrohaToriiCountMode?,
        asset: String?,
        scope: String?,
        network: UniversalWalletRegistry.IrohaNetwork
    ) async throws -> IrohaAccountAssetListResponse
    func assetDefinitions(baseURL: String?) async throws -> IrohaAssetDefinitionListResponse
    func submitTransaction(noritoBytes: Data, baseURL: String?) async throws -> IrohaTransactionSubmissionReceipt
    func transactionStatus(hash: String, baseURL: String?, scope: IrohaTransactionStatusScope) async throws -> IrohaPipelineTransactionStatusResponse
    func mcpCapabilities(network: UniversalWalletRegistry.IrohaNetwork, baseURL: String?) async throws -> Data
    func mcpJSONRPC(
        _ request: IrohaMcpJsonRPCRequest,
        network: UniversalWalletRegistry.IrohaNetwork,
        baseURL: String?
    ) async throws -> IrohaMcpJsonRPCResponse
}

final class IrohaToriiClient: IrohaToriiClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let defaultNetwork: UniversalWalletRegistry.IrohaNetwork
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        defaultNetwork: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.transport = transport
        self.defaultNetwork = defaultNetwork
        self.decoder = decoder
        self.encoder = encoder
    }

    func health(baseURL: String? = nil) async throws -> Data {
        try await transport.perform(urlRequest(url: try IrohaToriiRoutes.healthURL(baseURL: resolvedBaseURL(baseURL))))
    }

    func accounts(
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil
    ) async throws -> IrohaAccountListResponse {
        try await get(
            try IrohaToriiRoutes.accountsURL(
                baseURL: resolvedBaseURL(baseURL),
                limit: limit,
                offset: offset,
                countMode: countMode
            )
        )
    }

    func account(
        accountID: String,
        baseURL: String? = nil,
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira
    ) async throws -> IrohaAccountListItem {
        try await get(
            try IrohaToriiRoutes.accountURL(
                accountID: normalizeWalletAccountID(accountID, network: network),
                baseURL: resolvedBaseURL(baseURL, network: network)
            )
        )
    }

    func accountAssets(
        accountID: String,
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil,
        asset: String? = nil,
        scope: String? = nil,
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira
    ) async throws -> IrohaAccountAssetListResponse {
        try await get(
            try IrohaToriiRoutes.accountAssetsURL(
                accountID: normalizeWalletAccountID(accountID, network: network),
                baseURL: resolvedBaseURL(baseURL, network: network),
                limit: limit,
                offset: offset,
                countMode: countMode,
                asset: asset,
                scope: scope
            )
        )
    }

    func assetDefinitions(baseURL: String? = nil) async throws -> IrohaAssetDefinitionListResponse {
        try await get(try IrohaToriiRoutes.assetDefinitionsURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func submitTransaction(
        noritoBytes: Data,
        baseURL: String? = nil
    ) async throws -> IrohaTransactionSubmissionReceipt {
        var request = urlRequest(
            url: try IrohaToriiRoutes.submitTransactionURL(baseURL: resolvedBaseURL(baseURL)),
            method: "POST"
        )
        request.setValue("application/x-norito", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = noritoBytes

        return try decode(try await transport.perform(request))
    }

    func transactionStatus(
        hash: String,
        baseURL: String? = nil,
        scope: IrohaTransactionStatusScope = .auto
    ) async throws -> IrohaPipelineTransactionStatusResponse {
        try await get(
            try IrohaToriiRoutes.transactionStatusURL(
                hash: hash,
                baseURL: resolvedBaseURL(baseURL),
                scope: scope
            )
        )
    }

    func mcpCapabilities(
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira,
        baseURL: String? = nil
    ) async throws -> Data {
        try await transport.perform(
            urlRequest(url: try IrohaToriiRoutes.mcpURL(network: network, baseURL: resolvedBaseURL(baseURL, network: network)))
        )
    }

    func mcpJSONRPC(
        _ request: IrohaMcpJsonRPCRequest,
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira,
        baseURL: String? = nil
    ) async throws -> IrohaMcpJsonRPCResponse {
        var urlRequest = urlRequest(
            url: try IrohaToriiRoutes.mcpURL(network: network, baseURL: resolvedBaseURL(baseURL, network: network)),
            method: "POST"
        )
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try encoder.encode(request)

        return try decode(try await transport.perform(urlRequest))
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decode(try await transport.perform(urlRequest(url: url)))
    }

    private func normalizeWalletAccountID(
        _ accountID: String,
        network: UniversalWalletRegistry.IrohaNetwork
    ) throws -> String {
        try IrohaAddressCodec.parse(accountID, expectedDiscriminant: network.chainDiscriminant).i105
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }

    private func urlRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func resolvedBaseURL(
        _ baseURL: String?,
        network: UniversalWalletRegistry.IrohaNetwork? = nil
    ) throws -> String {
        if let baseURL {
            return baseURL
        }

        return try IrohaToriiRoutes.requireToriiBaseURL(network ?? defaultNetwork)
    }
}
