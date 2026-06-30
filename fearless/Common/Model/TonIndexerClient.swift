import Foundation

protocol TonIndexerClientProtocol {
    func health(baseURL: String?) async throws -> TonHealthStatus
    func contracts(baseURL: String?) async throws -> TonContractsResponse
    func serviceInfo(baseURL: String?) async throws -> TonIndexerServiceInfo
    func verifyServiceInfo(baseURL: String?) async throws -> TonIndexerServiceInfo
    func balance(address: String, baseURL: String?) async throws -> TonBalanceResponse
    func balances(address: String, baseURL: String?) async throws -> TonBalancesResponse
    func assets(address: String, baseURL: String?) async throws -> TonBalancesResponse
    func state(address: String, baseURL: String?) async throws -> TonAccountStateResponse
    func transactions(
        address: String,
        baseURL: String?,
        page: Int,
        cursorLt: String?,
        cursorHash: String?
    ) async throws -> TonTransactionsResponse
    func swaps(
        address: String,
        baseURL: String?,
        limit: Int,
        fromUtime: Int64?,
        toUtime: Int64?,
        payToken: String?,
        receiveToken: String?,
        executionType: TonSwapExecutionType?,
        status: TonSwapStatus?,
        includeReverse: Bool?
    ) async throws -> TonSwapsResponse
    func jettonTransferPayload(jetton: String, owner: String, baseURL: String?) async throws -> TonJettonTransferPayloadResponse
    func runGetMethod(address: String, method: String, stack: [[TonJSONValue]], baseURL: String?) async throws -> TonRunGetMethodResponse
    func runGetMethods(calls: [TonRunGetMethodRequest], baseURL: String?) async throws -> TonRunGetMethodsResponse
}

enum TonIndexerClientError: Error, Equatable {
    case unexpectedServiceInfo(TonIndexerServiceInfo)
}

final class TonIndexerClient: TonIndexerClientProtocol {
    private let transport: UniversalWalletHTTPTransport
    private let defaultBaseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        defaultBaseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.transport = transport
        self.defaultBaseURL = defaultBaseURL
        self.decoder = decoder
        self.encoder = encoder
    }

    func health(baseURL: String? = nil) async throws -> TonHealthStatus {
        try await get(try TonIndexerRoutes.healthURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func contracts(baseURL: String? = nil) async throws -> TonContractsResponse {
        try await get(try TonIndexerRoutes.contractsURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func serviceInfo(baseURL: String? = nil) async throws -> TonIndexerServiceInfo {
        try await get(try TonIndexerRoutes.serviceInfoURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func verifyServiceInfo(baseURL: String? = nil) async throws -> TonIndexerServiceInfo {
        let info = try await serviceInfo(baseURL: baseURL)
        guard info.isExpectedTIServiceInfo else {
            throw TonIndexerClientError.unexpectedServiceInfo(info)
        }
        return info
    }

    func balance(address: String, baseURL: String? = nil) async throws -> TonBalanceResponse {
        try await get(try TonIndexerRoutes.balanceURL(address: address, baseURL: resolvedBaseURL(baseURL)))
    }

    func balances(address: String, baseURL: String? = nil) async throws -> TonBalancesResponse {
        try await get(try TonIndexerRoutes.balancesURL(address: address, baseURL: resolvedBaseURL(baseURL)))
    }

    func assets(address: String, baseURL: String? = nil) async throws -> TonBalancesResponse {
        try await get(try TonIndexerRoutes.assetsURL(address: address, baseURL: resolvedBaseURL(baseURL)))
    }

    func state(address: String, baseURL: String? = nil) async throws -> TonAccountStateResponse {
        try await get(try TonIndexerRoutes.stateURL(address: address, baseURL: resolvedBaseURL(baseURL)))
    }

    func transactions(
        address: String,
        baseURL: String? = nil,
        page: Int = TonIndexerRoutes.defaultTxPage,
        cursorLt: String? = nil,
        cursorHash: String? = nil
    ) async throws -> TonTransactionsResponse {
        try await get(
            try TonIndexerRoutes.transactionsURL(
                address: address,
                baseURL: resolvedBaseURL(baseURL),
                page: page,
                cursorLt: cursorLt,
                cursorHash: cursorHash
            )
        )
    }

    func swaps(
        address: String,
        baseURL: String? = nil,
        limit: Int = TonIndexerRoutes.defaultSwapLimit,
        fromUtime: Int64? = nil,
        toUtime: Int64? = nil,
        payToken: String? = nil,
        receiveToken: String? = nil,
        executionType: TonSwapExecutionType? = nil,
        status: TonSwapStatus? = nil,
        includeReverse: Bool? = nil
    ) async throws -> TonSwapsResponse {
        try await get(
            try TonIndexerRoutes.swapsURL(
                address: address,
                baseURL: resolvedBaseURL(baseURL),
                limit: limit,
                fromUtime: fromUtime,
                toUtime: toUtime,
                payToken: payToken,
                receiveToken: receiveToken,
                executionType: executionType,
                status: status,
                includeReverse: includeReverse
            )
        )
    }

    func jettonTransferPayload(
        jetton: String,
        owner: String,
        baseURL: String? = nil
    ) async throws -> TonJettonTransferPayloadResponse {
        try await get(
            try TonIndexerRoutes.jettonTransferPayloadURL(
                jetton: jetton,
                owner: owner,
                baseURL: resolvedBaseURL(baseURL)
            )
        )
    }

    func runGetMethod(
        address: String,
        method: String,
        stack: [[TonJSONValue]] = [],
        baseURL: String? = nil
    ) async throws -> TonRunGetMethodResponse {
        let body = try TonIndexerRoutes.runGetMethodRequest(address: address, method: method, stack: stack)
        return try await postJSON(body, to: try TonIndexerRoutes.runGetMethodURL(baseURL: resolvedBaseURL(baseURL)))
    }

    func runGetMethods(
        calls: [TonRunGetMethodRequest],
        baseURL: String? = nil
    ) async throws -> TonRunGetMethodsResponse {
        let body = try TonIndexerRoutes.runGetMethodsRequest(calls: calls)
        return try await postJSON(body, to: try TonIndexerRoutes.runGetMethodsURL(baseURL: resolvedBaseURL(baseURL)))
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decode(try await transport.perform(urlRequest(url: url)))
    }

    private func postJSON<Body: Encodable, Response: Decodable>(_ body: Body, to url: URL) async throws -> Response {
        var request = urlRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        return try decode(try await transport.perform(request))
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
