import Foundation

enum IrohaToriiRouteError: Error, Equatable {
    case invalidBaseURL
    case missingToriiBaseURL
    case invalidPath
    case invalidAccountID
    case invalidAsset
    case invalidScope
    case invalidHash
    case invalidLimit
    case invalidOffset
    case invalidJSONRPCID
    case invalidMCPMethod
}

enum IrohaToriiCountMode: String, Codable {
    case bounded
    case exact
}

enum IrohaTransactionStatusScope: String, Codable {
    case local
    case auto
    case global
}

enum IrohaToriiRoutes {
    static let defaultLimit = 100
    static let maxLimit = 500

    static func healthURL(baseURL: String? = nil) throws -> URL {
        try makeURL("\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/health")
    }

    static func mcpURL(
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira,
        baseURL: String? = nil
    ) throws -> URL {
        let base = try resolvedBaseURL(baseURL, network: network)
        return try makeURL("\(normalizeBaseURL(base))\(normalizePath(network.mcpPath))")
    }

    static func accountsURL(
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil
    ) throws -> URL {
        try makeURL(
            base: "\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/accounts",
            queryItems: pageQuery(limit: limit, offset: offset, countMode: countMode)
        )
    }

    static func accountURL(accountID: String, baseURL: String? = nil) throws -> URL {
        try makeURL(
            "\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/accounts/\(encodePathSegment(normalizeAccountID(accountID)))"
        )
    }

    static func accountAssetsURL(
        accountID: String,
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil,
        asset: String? = nil,
        scope: String? = nil
    ) throws -> URL {
        var queryItems = try pageQuery(limit: limit, offset: offset, countMode: countMode)
        if let asset {
            queryItems.append(URLQueryItem(name: "asset", value: try normalizeAssetSelector(asset)))
        }
        if let scope {
            queryItems.append(URLQueryItem(name: "scope", value: try normalizeScope(scope)))
        }

        return try makeURL(
            base: "\(accountURL(accountID: accountID, baseURL: baseURL).absoluteString)/assets",
            queryItems: queryItems
        )
    }

    static func accountHistoryURL(
        accountID: String,
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil,
        assetID: String? = nil
    ) throws -> URL {
        var queryItems = try pageQuery(limit: limit, offset: offset, countMode: countMode)
        if let assetID {
            queryItems.append(
                URLQueryItem(name: "asset_id", value: try normalizeAssetSelector(assetID))
            )
        }

        return try makeURL(
            base: "\(accountURL(accountID: accountID, baseURL: baseURL).absoluteString)/history",
            queryItems: queryItems
        )
    }

    static func assetDefinitionsURL(
        baseURL: String? = nil,
        limit: Int? = nil,
        offset: Int64? = nil,
        countMode: IrohaToriiCountMode? = nil
    ) throws -> URL {
        try makeURL(
            base: "\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/assets/definitions",
            queryItems: pageQuery(limit: limit, offset: offset, countMode: countMode)
        )
    }

    static func assetDefinitionURL(
        selector: String,
        baseURL: String? = nil
    ) throws -> URL {
        try makeURL(
            "\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/assets/definitions/\(encodePathSegment(normalizeAssetSelector(selector)))"
        )
    }

    static func assetAliasResolutionURL(baseURL: String? = nil) throws -> URL {
        try makeURL("\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/assets/aliases/resolve")
    }

    static func submitTransactionURL(baseURL: String? = nil) throws -> URL {
        try makeURL("\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/pipeline/transactions")
    }

    static func transactionStatusURL(
        hash: String,
        baseURL: String? = nil,
        scope: IrohaTransactionStatusScope = .auto
    ) throws -> URL {
        try makeURL(
            base: "\(normalizeBaseURL(try resolvedBaseURL(baseURL)))/v1/pipeline/transactions/status",
            queryItems: [
                URLQueryItem(name: "hash", value: try normalizeHash(hash)),
                URLQueryItem(name: "scope", value: scope.rawValue)
            ]
        )
    }

    static func mcpJSONRPCRequest(
        method: String,
        id: String,
        params: [String: IrohaJSONValue]? = nil
    ) throws -> IrohaMcpJsonRPCRequest {
        IrohaMcpJsonRPCRequest(
            id: try normalizeJSONRPCID(id),
            method: try normalizeMCPMethod(method),
            params: params
        )
    }

    static func normalizeBaseURL(_ baseURL: String) throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else {
            throw IrohaToriiRouteError.invalidBaseURL
        }

        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw IrohaToriiRouteError.invalidBaseURL
        }

        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func normalizeAccountID(_ accountID: String) throws -> String {
        try normalizePathValue(accountID, error: .invalidAccountID)
    }

    static func normalizeAssetSelector(_ asset: String) throws -> String {
        let normalized = asset.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= 256,
              !containsASCIIWhitespaceOrControl(normalized),
              normalized.range(of: "[/?]", options: .regularExpression) == nil else {
            throw IrohaToriiRouteError.invalidAsset
        }

        return normalized
    }

    static func requireToriiBaseURL(_ network: UniversalWalletRegistry.IrohaNetwork) throws -> String {
        guard let url = network.toriiBaseURL else {
            throw IrohaToriiRouteError.missingToriiBaseURL
        }

        return url.absoluteString
    }

    private static func resolvedBaseURL(
        _ baseURL: String?,
        network: UniversalWalletRegistry.IrohaNetwork = UniversalWalletRegistry.taira
    ) throws -> String {
        if let baseURL {
            return baseURL
        }

        return try requireToriiBaseURL(network)
    }

    private static func normalizeScope(_ scope: String) throws -> String {
        let normalized = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized == "global" || matches(normalized, "^dataspace:[A-Za-z0-9._:-]{1,128}$") else {
            throw IrohaToriiRouteError.invalidScope
        }

        return normalized
    }

    private static func normalizePath(_ path: String) throws -> String {
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("/"),
              !normalized.contains(".."),
              !normalized.contains("?"),
              !normalized.contains("#") else {
            throw IrohaToriiRouteError.invalidPath
        }

        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .isEmpty ? "/" : "/" + normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func normalizePathValue(_ value: String, error: IrohaToriiRouteError) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= 256,
              !containsASCIIWhitespaceOrControl(normalized),
              normalized.range(of: "[/?#]", options: .regularExpression) == nil else {
            throw error
        }

        return normalized
    }

    private static func normalizeHash(_ hash: String) throws -> String {
        let normalized = hash
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropPrefix("0x")
            .lowercased()
        guard matches(normalized, "^[0-9a-f]{64}$") else {
            throw IrohaToriiRouteError.invalidHash
        }

        return normalized
    }

    private static func normalizeJSONRPCID(_ id: String) throws -> String {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^[A-Za-z0-9._:-]{1,64}$") else {
            throw IrohaToriiRouteError.invalidJSONRPCID
        }

        return normalized
    }

    private static func normalizeMCPMethod(_ method: String) throws -> String {
        let normalized = method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^[A-Za-z][A-Za-z0-9_/.-]{0,127}$") else {
            throw IrohaToriiRouteError.invalidMCPMethod
        }

        return normalized
    }

    private static func pageQuery(
        limit: Int?,
        offset: Int64?,
        countMode: IrohaToriiCountMode?
    ) throws -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []

        if let limit {
            guard (1 ... maxLimit).contains(limit) else {
                throw IrohaToriiRouteError.invalidLimit
            }
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset {
            guard offset >= 0 else {
                throw IrohaToriiRouteError.invalidOffset
            }
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if let countMode {
            queryItems.append(URLQueryItem(name: "count_mode", value: countMode.rawValue))
        }

        return queryItems
    }

    private static func makeURL(base: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw IrohaToriiRouteError.invalidBaseURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw IrohaToriiRouteError.invalidBaseURL
        }

        return url
    }

    private static func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw IrohaToriiRouteError.invalidBaseURL
        }

        return url
    }

    private static func encodePathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? value
    }

    private static func containsASCIIWhitespaceOrControl(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0.value <= 0x20 || $0.value == 0x7F }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static let pathSegmentAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

private extension String {
    func dropPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

enum IrohaJSONValue: Codable, Equatable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case object([String: IrohaJSONValue])
    case array([IrohaJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: IrohaJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([IrohaJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct IrohaAccountListResponse: Codable, Equatable {
    let items: [IrohaAccountListItem]
    let hasMore: Bool
    let countMode: String
    let total: Int64?

    private enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case countMode = "count_mode"
        case total
    }
}

struct IrohaAccountListItem: Codable, Equatable {
    let id: String
    let primaryAlias: String?
    let primaryAliasName: String?
    let primaryAliasDataspace: String?
    let primaryAliasDomain: String?
    let hasPrimaryAlias: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case primaryAlias = "primary_alias"
        case primaryAliasName = "primary_alias_name"
        case primaryAliasDataspace = "primary_alias_dataspace"
        case primaryAliasDomain = "primary_alias_domain"
        case hasPrimaryAlias = "has_primary_alias"
    }
}

struct IrohaAccountAssetListResponse: Codable, Equatable {
    let items: [IrohaAccountAssetListItem]
    let hasMore: Bool?
    let countMode: String?
    let total: Int64?

    private enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case countMode = "count_mode"
        case total
    }
}

struct IrohaAccountAssetListItem: Codable, Equatable {
    let accountID: String?
    let asset: String
    let assetID: String?
    let assetName: String?
    let assetAlias: String?
    let quantity: String
    let scope: String?

    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case asset
        case assetID = "asset_id"
        case assetName = "asset_name"
        case assetAlias = "asset_alias"
        case quantity
        case scope
    }
}

struct IrohaAssetDefinitionListResponse: Codable, Equatable {
    let items: [IrohaAssetDefinitionListItem]
    let hasMore: Bool?
    let countMode: String?
    let total: Int64?

    private enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case countMode = "count_mode"
        case total
    }
}

struct IrohaAccountHistoryResponse: Codable, Equatable {
    let items: [IrohaAccountHistoryItem]
    let hasMore: Bool?
    let countMode: String?
    let total: Int64?

    private enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case countMode = "count_mode"
        case total
    }
}

struct IrohaAccountHistoryItem: Codable, Equatable {
    let id: String
    let source: String?
    let type: String
    let timestampMs: UInt64?
    let status: String
    let resultOk: Bool?
    let direction: String
    let accountID: String
    let counterpartyAccountID: String?
    let assetID: String?
    let assetDefinitionID: String?
    let amount: String?
    let transactionHash: String?
    let operationID: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case type
        case timestampMs = "timestamp_ms"
        case status
        case resultOk = "result_ok"
        case direction
        case accountID = "account_id"
        case counterpartyAccountID = "counterparty_account_id"
        case assetID = "asset_id"
        case assetDefinitionID = "asset_definition_id"
        case amount
        case transactionHash = "tx_hash"
        case operationID = "operation_id"
    }
}

struct IrohaAssetDefinitionListItem: Codable, Equatable {
    let id: String
    let name: String?
    let alias: String?
    let ownedBy: String?
    let metadata: [String: IrohaJSONValue]?
    let aliasBinding: [String: IrohaJSONValue]?
    let spec: IrohaAssetDefinitionSpec?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case alias
        case ownedBy = "owned_by"
        case metadata
        case aliasBinding = "alias_binding"
        case spec
    }
}

struct IrohaAssetDefinitionSpec: Codable, Equatable {
    static let maximumScale = 28

    let scale: Int?

    var fixedPointAdapterPrecision: UInt16? {
        guard let scale else {
            return UInt16(Self.maximumScale)
        }

        guard (0 ... Self.maximumScale).contains(scale) else {
            return nil
        }

        return UInt16(scale)
    }
}

struct IrohaAssetAliasResolutionRequest: Codable, Equatable {
    let alias: String
}

struct IrohaAssetAliasResolution: Codable, Equatable {
    let alias: String
    let assetDefinitionID: String
    let assetName: String
    let description: String?
    let logo: String?
    let source: String?
    let aliasBinding: IrohaAssetDefinitionAliasBinding?

    private enum CodingKeys: String, CodingKey {
        case alias
        case assetDefinitionID = "asset_definition_id"
        case assetName = "asset_name"
        case description
        case logo
        case source
        case aliasBinding = "alias_binding"
    }
}

struct IrohaAssetDefinitionAliasBinding: Codable, Equatable {
    let alias: String
    let status: String
    let leaseExpiryMs: UInt64?
    let graceUntilMs: UInt64?
    let boundAtMs: UInt64

    private enum CodingKeys: String, CodingKey {
        case alias
        case status
        case leaseExpiryMs = "lease_expiry_ms"
        case graceUntilMs = "grace_until_ms"
        case boundAtMs = "bound_at_ms"
    }
}

struct IrohaTransactionSubmissionReceipt: Codable, Equatable {
    let payload: IrohaTransactionSubmissionPayload
    let signature: IrohaJSONValue?
}

struct IrohaTransactionSubmissionPayload: Codable, Equatable {
    let txHash: String
    let entrypointHash: String
    let signedTransactionHash: String?
    let submittedAtMs: Int64
    let submittedAtHeight: Int64
    let signer: IrohaJSONValue?

    private enum CodingKeys: String, CodingKey {
        case txHash = "tx_hash"
        case entrypointHash = "entrypoint_hash"
        case signedTransactionHash = "signed_transaction_hash"
        case submittedAtMs = "submitted_at_ms"
        case submittedAtHeight = "submitted_at_height"
        case signer
    }
}

struct IrohaPipelineTransactionStatusResponse: Codable, Equatable {
    let hash: String
    let status: IrohaPipelineTransactionStatus
    let scope: String
    let resolvedFrom: String

    private enum CodingKeys: String, CodingKey {
        case hash
        case status
        case scope
        case resolvedFrom = "resolved_from"
    }
}

struct IrohaPipelineTransactionStatus: Codable, Equatable {
    let kind: String
    let blockHeight: Int64?
    let rejectionReason: IrohaJSONValue?

    private enum CodingKeys: String, CodingKey {
        case kind
        case blockHeight = "block_height"
        case rejectionReason = "rejection_reason"
    }
}

struct IrohaErrorEnvelope: Codable, Equatable {
    let code: String
    let message: String
    let details: IrohaJSONValue?
}

struct IrohaMcpJsonRPCRequest: Codable, Equatable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: [String: IrohaJSONValue]?

    init(jsonrpc: String = "2.0", id: String, method: String, params: [String: IrohaJSONValue]? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

struct IrohaMcpJsonRPCResponse: Codable, Equatable {
    let jsonrpc: String
    let id: IrohaJSONValue?
    let result: IrohaJSONValue?
    let error: IrohaMcpJsonRPCError?
}

struct IrohaMcpJsonRPCError: Codable, Equatable {
    let code: Int
    let message: String
    let data: IrohaJSONValue?
}
