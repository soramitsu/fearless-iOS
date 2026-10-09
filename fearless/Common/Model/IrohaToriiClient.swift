import Foundation

protocol IrohaToriiHTTPTransport: UniversalWalletHTTPTransport {}

final class IrohaNoRedirectURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class IrohaNoRedirectHTTPTransport: IrohaToriiHTTPTransport {
    private let redirectDelegate: IrohaNoRedirectURLSessionDelegate
    private let transport: URLSessionUniversalWalletHTTPTransport

    init(configuration: URLSessionConfiguration = .ephemeral) {
        let redirectDelegate = IrohaNoRedirectURLSessionDelegate()
        self.redirectDelegate = redirectDelegate
        transport = URLSessionUniversalWalletHTTPTransport(
            session: URLSession(
                configuration: configuration,
                delegate: redirectDelegate,
                delegateQueue: nil
            )
        )
    }

    func perform(_ request: URLRequest) async throws -> Data {
        try await transport.perform(request)
    }

    func performResponse(_ request: URLRequest) async throws -> UniversalWalletHTTPResponse {
        try await transport.performResponse(request)
    }
}

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
    func assetDefinitions(
        baseURL: String?,
        limit: Int?,
        offset: Int64?,
        countMode: IrohaToriiCountMode?
    ) async throws -> IrohaAssetDefinitionListResponse
    func submitTransactionAndWait(
        noritoBytes: Data,
        expectedHash: String,
        timeoutMilliseconds: Int64,
        pollIntervalMilliseconds: Int64,
        network: UniversalWalletRegistry.IrohaNetwork,
        baseURL: String?
    ) async throws -> IrohaSubmitAndWaitOutcome
    func transactionStatus(hash: String, baseURL: String?, scope: IrohaTransactionStatusScope) async throws -> IrohaPipelineTransactionStatusResponse
    func mcpCapabilities(network: UniversalWalletRegistry.IrohaNetwork, baseURL: String?) async throws -> Data
    func mcpJSONRPC(
        _ request: IrohaMcpJsonRPCRequest,
        network: UniversalWalletRegistry.IrohaNetwork,
        baseURL: String?
    ) async throws -> IrohaMcpJsonRPCResponse
}

final class IrohaToriiClient: IrohaToriiClientProtocol {
    private let transport: IrohaToriiHTTPTransport
    private let defaultNetwork: UniversalWalletRegistry.IrohaNetwork
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        transport: IrohaToriiHTTPTransport = IrohaNoRedirectHTTPTransport(),
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
        try await transport.performResponse(
            urlRequest(url: try IrohaToriiRoutes.healthURL(baseURL: resolvedBaseURL(baseURL)))
        ).data
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

    func assetDefinitions(
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil
    ) async throws -> IrohaAssetDefinitionListResponse {
        try await get(
            try IrohaToriiRoutes.assetDefinitionsURL(
                baseURL: resolvedBaseURL(baseURL),
                limit: limit,
                offset: offset,
                countMode: countMode
            )
        )
    }

    func submitTransactionAndWait(
        noritoBytes: Data,
        expectedHash: String,
        timeoutMilliseconds: Int64,
        pollIntervalMilliseconds: Int64,
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira,
        baseURL: String? = nil
    ) async throws -> IrohaSubmitAndWaitOutcome {
        guard !noritoBytes.isEmpty,
              let canonicalExpectedHash = canonicalTransactionHash(expectedHash),
              (1 ... 300_000).contains(timeoutMilliseconds),
              (100 ... 60000).contains(pollIntervalMilliseconds) else {
            throw IrohaSubmitAndWaitError.invalidResponse
        }

        let response = try await mcpJSONRPC(
            IrohaMcpJsonRPCRequest(
                id: "submit-\(canonicalExpectedHash.prefix(16))",
                method: "tools/call",
                params: [
                    "name": .string("iroha.transactions.submit_and_wait"),
                    "arguments": .object([
                        "accept": .string("application/json"),
                        "body_base64": .string(noritoBytes.base64EncodedString()),
                        "hash": .string(canonicalExpectedHash),
                        "poll_interval_ms": .int(pollIntervalMilliseconds),
                        "status_accept": .string("application/json"),
                        "terminal_statuses": .array([.string("Applied")]),
                        "timeout_ms": .int(timeoutMilliseconds)
                    ])
                ]
            ),
            network: network,
            baseURL: baseURL
        )

        if let error = response.error {
            throw classifySubmitAndWaitError(message: error.message)
        }
        guard case let .object(toolResult)? = response.result else {
            throw IrohaSubmitAndWaitError.invalidResponse
        }
        if toolResult["isError"] == .bool(true) {
            let message: String
            if case let .object(errorEnvelope)? = toolResult["structuredContent"],
               case let .string(errorMessage)? = errorEnvelope["message"] {
                message = errorMessage
            } else {
                message = "MCP submit-and-wait returned a tool error"
            }
            throw classifySubmitAndWaitError(message: message)
        }
        guard let structuredContent = toolResult["structuredContent"],
              let outcome = try? decoder.decode(
                  IrohaSubmitAndWaitOutcome.self,
                  from: encoder.encode(structuredContent)
              ),
              outcome.status == 200,
              outcome.terminalStatuses == [.applied],
              outcome.attempts > 0,
              outcome.elapsedMilliseconds >= 0,
              (200 ... 299).contains(outcome.submit.status),
              (200 ... 299).contains(outcome.finalStatus.status),
              isJSONMediaType(outcome.submit.contentType),
              isJSONMediaType(outcome.finalStatus.contentType),
              canonicalTransactionHash(outcome.hash) == canonicalExpectedHash,
              canonicalTransactionHash(outcome.transactionHash) == canonicalExpectedHash,
              canonicalTransactionHash(outcome.submit.body.payload.entrypointHash) == canonicalExpectedHash,
              canonicalTransactionHash(outcome.finalStatus.body.hash) == canonicalExpectedHash,
              outcome.terminalKind == .applied,
              outcome.finalStatus.body.status.kind == .applied else {
            throw IrohaSubmitAndWaitError.invalidResponse
        }
        try validateFanoutHeaders(headers: outcome.submit.headers)
        try validateFanoutHeaders(headers: outcome.finalStatus.headers)

        return outcome
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
        try completeMCPData(
            try await transport.performResponse(
                urlRequest(
                    url: try IrohaToriiRoutes.mcpURL(
                        network: network,
                        baseURL: resolvedBaseURL(baseURL, network: network)
                    )
                )
            )
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

        let response: IrohaMcpJsonRPCResponse = try decode(
            completeMCPData(try await transport.performResponse(urlRequest))
        )
        let hasExactlyOnePayload = (response.result == nil) != (response.error == nil)
        guard response.jsonrpc == "2.0",
              response.id == .string(request.id),
              hasExactlyOnePayload else {
            throw IrohaToriiReadError.invalidJSONRPCResponse
        }

        return response
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try decode(completeRoutedData(try await transport.performResponse(urlRequest(url: url))))
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

    private func completeRoutedData(_ response: UniversalWalletHTTPResponse) throws -> Data {
        let headers = try normalizedResponseHeaders(response.headers)
        try validateFanoutHeaders(headers: headers)
        try requireJSONContentType(headers)

        return try requireSuccessfulData(response)
    }

    private func completeMCPData(_ response: UniversalWalletHTTPResponse) throws -> Data {
        let headers = try normalizedResponseHeaders(response.headers)
        try requireJSONContentType(headers)

        return try requireSuccessfulData(response)
    }

    private func requireSuccessfulData(_ response: UniversalWalletHTTPResponse) throws -> Data {
        guard !response.data.isEmpty else {
            throw IrohaToriiReadError.emptySuccessfulResponse
        }

        return response.data
    }

    private func validateFanoutHeaders(headers: [String: String]) throws {
        var normalized: [String: String] = [:]
        for entry in headers {
            let name = entry.key.lowercased()
            guard normalized[name] == nil else {
                throw IrohaToriiReadError.malformedFanoutHeaders
            }
            normalized[name] = entry.value
        }
        try validateFanoutHeaders { normalized[$0] }
    }

    private func normalizedResponseHeaders(_ headers: [AnyHashable: Any]) throws -> [String: String] {
        var normalized: [String: String] = [:]
        for entry in headers {
            let name = String(describing: entry.key).lowercased()
            guard !name.isEmpty, normalized[name] == nil else {
                throw IrohaToriiReadError.malformedResponseHeaders
            }
            normalized[name] = String(describing: entry.value)
        }
        return normalized
    }

    private func requireJSONContentType(_ headers: [String: String]) throws {
        guard isJSONMediaType(headers["content-type"]) else {
            throw IrohaToriiReadError.invalidJSONContentType
        }
    }

    private func isJSONMediaType(_ value: String?) -> Bool {
        value?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "application/json"
    }

    private func validateFanoutHeaders(header: (String) -> String?) throws {
        let headerNames = [
            "x-iroha-fanout-routes-attempted",
            "x-iroha-fanout-routes-succeeded",
            "x-iroha-fanout-routes-failed",
            "x-iroha-fanout-routes-denied",
            "x-iroha-fanout-routes-unavailable",
            "x-iroha-fanout-routes-not-found"
        ]
        let rawValues = headerNames.map(header)
        let values = try rawValues.map { rawValue -> Int in
            guard let rawValue,
                  rawValue.range(of: "^(0|[1-9][0-9]*)$", options: .regularExpression) != nil,
                  let value = Int(rawValue) else {
                throw IrohaToriiReadError.malformedFanoutHeaders
            }

            return value
        }
        let fanout = IrohaToriiFanoutStatus(
            attempted: values[0],
            succeeded: values[1],
            failed: values[2],
            denied: values[3],
            unavailable: values[4],
            notFound: values[5]
        )
        guard fanout.isValid else {
            throw IrohaToriiReadError.malformedFanoutHeaders
        }
        guard fanout.isComplete else {
            throw IrohaToriiReadError.degraded(fanout)
        }
    }

    private func classifySubmitAndWaitError(message: String) -> IrohaSubmitAndWaitError {
        if message.range(of: "last_status=Rejected", options: .caseInsensitive) != nil {
            return .rejected(message)
        }
        if message.range(of: "last_status=Expired", options: .caseInsensitive) != nil {
            return .expired(message)
        }
        if message.range(
            of: "timed out waiting for terminal transaction status",
            options: .caseInsensitive
        ) != nil {
            return .timeout(message)
        }
        return .rpc(message)
    }

    private func canonicalTransactionHash(_ value: String) -> String? {
        guard value.range(
            of: "^[0-9a-f]{63}[13579bdf]$",
            options: .regularExpression
        ) != nil else {
            return nil
        }
        return value
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
