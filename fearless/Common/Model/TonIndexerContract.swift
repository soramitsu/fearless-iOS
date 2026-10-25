import Foundation

enum TonIndexerRouteError: Error, Equatable {
    case invalidBaseURL
    case invalidAddress
    case invalidPage
    case cursorMismatch
    case invalidCursor
    case invalidLimit
    case invalidUtime
    case invalidUtimeRange
    case invalidTokenFilter
    case invalidMethod
    case invalidCalls
}

enum TonSwapExecutionType: String, Codable {
    case market
    case limit
    case twap
    case unknown
}

enum TonSwapStatus: String, Codable {
    case success
    case failed
    case pending
}

enum TonIndexerRoutes {
    static let defaultTxPage = 1
    static let defaultSwapLimit = 100
    static let maxSwapLimit = 500
    static let maxRunGetBatchSize = 64

    static func healthURL(baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/health")
    }

    static func contractsURL(baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/contracts")
    }

    static func serviceInfoURL(baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/service-info")
    }

    static func balanceURL(address: String, baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try accountURL(baseURL: baseURL, address: address, section: "balance")
    }

    static func balancesURL(address: String, baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try accountURL(baseURL: baseURL, address: address, section: "balances")
    }

    static func assetsURL(address: String, baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try accountURL(baseURL: baseURL, address: address, section: "assets")
    }

    static func stateURL(address: String, baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try accountURL(baseURL: baseURL, address: address, section: "state")
    }

    static func transactionsURL(
        address: String,
        baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString,
        page: Int = defaultTxPage,
        cursorLt: String? = nil,
        cursorHash: String? = nil
    ) throws -> URL {
        guard page >= 1 else {
            throw TonIndexerRouteError.invalidPage
        }
        guard (cursorLt == nil) == (cursorHash == nil) else {
            throw TonIndexerRouteError.cursorMismatch
        }

        guard var components = URLComponents(
            string: "\(try accountURL(baseURL: baseURL, address: address, section: "txs").absoluteString)"
        ) else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let cursorLt, let cursorHash {
            queryItems.append(URLQueryItem(name: "cursor_lt", value: try normalizeLt(cursorLt)))
            queryItems.append(URLQueryItem(name: "cursor_hash", value: try normalizeHash(cursorHash)))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        return url
    }

    static func swapsURL(
        address: String,
        baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString,
        limit: Int = defaultSwapLimit,
        fromUtime: Int64? = nil,
        toUtime: Int64? = nil,
        payToken: String? = nil,
        receiveToken: String? = nil,
        executionType: TonSwapExecutionType? = nil,
        status: TonSwapStatus? = nil,
        includeReverse: Bool? = nil
    ) throws -> URL {
        guard (1 ... maxSwapLimit).contains(limit) else {
            throw TonIndexerRouteError.invalidLimit
        }
        if fromUtime.map({ $0 < 1 }) == true || toUtime.map({ $0 < 1 }) == true {
            throw TonIndexerRouteError.invalidUtime
        }
        if let fromUtime, let toUtime, fromUtime > toUtime {
            throw TonIndexerRouteError.invalidUtimeRange
        }

        guard var components = URLComponents(
            string: "\(try accountURL(baseURL: baseURL, address: address, section: "swaps").absoluteString)"
        ) else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        fromUtime.map { queryItems.append(URLQueryItem(name: "from_utime", value: String($0))) }
        toUtime.map { queryItems.append(URLQueryItem(name: "to_utime", value: String($0))) }
        if let payToken {
            queryItems.append(URLQueryItem(name: "pay_token", value: try normalizeTokenFilter(payToken)))
        }
        if let receiveToken {
            queryItems.append(URLQueryItem(name: "receive_token", value: try normalizeTokenFilter(receiveToken)))
        }
        executionType.map { queryItems.append(URLQueryItem(name: "execution_type", value: $0.rawValue)) }
        status.map { queryItems.append(URLQueryItem(name: "status", value: $0.rawValue)) }
        includeReverse.map { queryItems.append(URLQueryItem(name: "include_reverse", value: $0 ? "true" : "false")) }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        return url
    }

    static func jettonTransferPayloadURL(
        jetton: String,
        owner: String,
        baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString
    ) throws -> URL {
        try makeURL(
            "\(normalizeBaseURL(baseURL))/api/indexer/v1/jettons/\(normalizeAddress(jetton))/transfer/\(normalizeAddress(owner))/payload"
        )
    }

    static func runGetMethodURL(baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/runGetMethod")
    }

    static func runGetMethodsURL(baseURL: String = UniversalWalletRegistry.tonIndexerBaseURL.absoluteString) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/runGetMethods")
    }

    static func runGetMethodRequest(
        address: String,
        method: String,
        stack: [[TonJSONValue]] = []
    ) throws -> TonRunGetMethodRequest {
        TonRunGetMethodRequest(
            address: try normalizeAddress(address),
            method: try normalizeGetterMethod(method),
            stack: stack
        )
    }

    static func runGetMethodsRequest(calls: [TonRunGetMethodRequest]) throws -> TonRunGetMethodsRequest {
        guard !calls.isEmpty, calls.count <= maxRunGetBatchSize else {
            throw TonIndexerRouteError.invalidCalls
        }

        return TonRunGetMethodsRequest(calls: calls)
    }

    static func normalizeBaseURL(_ baseURL: String) throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func normalizeAddress(_ address: String) throws -> String {
        let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if matches(normalized, "^[A-Za-z0-9_-]{48}$") {
            return normalized
        }

        let lowercased = normalized.lowercased()
        guard matches(lowercased, "^(?:-1|0):[0-9a-f]{64}$") else {
            throw TonIndexerRouteError.invalidAddress
        }

        return lowercased
    }

    private static func accountURL(baseURL: String, address: String, section: String) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/accounts/\(normalizeAddress(address))/\(section)")
    }

    private static func normalizeLt(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^\\d+$") else {
            throw TonIndexerRouteError.invalidCursor
        }

        return normalized
    }

    private static func normalizeHash(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^[A-Za-z0-9_+/=-]{40,64}$") else {
            throw TonIndexerRouteError.invalidCursor
        }

        return normalized
    }

    private static func normalizeTokenFilter(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^[A-Za-z0-9._:-]{1,32}$") else {
            throw TonIndexerRouteError.invalidTokenFilter
        }

        return normalized
    }

    private static func normalizeGetterMethod(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matches(normalized, "^[A-Za-z_][A-Za-z0-9_]{0,63}$") else {
            throw TonIndexerRouteError.invalidMethod
        }

        return normalized
    }

    private static func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw TonIndexerRouteError.invalidBaseURL
        }

        return url
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum TonJSONValue: Codable, Equatable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case object([String: TonJSONValue])
    case array([TonJSONValue])
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
        } else if let value = try? container.decode([String: TonJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([TonJSONValue].self) {
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

struct TonHealthStatus: Codable, Equatable {
    let lastMasterSeqno: Int64?
    let indexerLagSec: Double?
    let liteserverPoolStatus: String?
}

struct TonContractsResponse: Codable, Equatable {
    let network: String?
    let count: Int
    let contracts: [String: String]
}

struct TonIndexerServiceInfo: Codable, Equatable {
    let schemaVersion: Int
    let serviceId: String
    let serviceName: String
    let ecosystem: String
    let chainId: String
    let network: String
    let publicBaseUrl: String
    let readOnly: Bool
    let capabilities: [String]
    let endpoints: [String: String]

    var isExpectedTIServiceInfo: Bool {
        schemaVersion == 1 &&
            serviceId == "ti.soramitsu.io" &&
            ecosystem == "ton" &&
            chainId == "ton:mainnet" &&
            publicBaseUrl == "https://ti.soramitsu.io" &&
            readOnly
    }
}

struct TonBalanceResponse: Codable, Equatable {
    let ton: TonNativeBalance
    let jettons: [TonIndexerJettonBalance]
    let confirmed: Bool
    let updatedAt: Int64
    let network: String

    private enum CodingKeys: String, CodingKey {
        case ton
        case jettons
        case confirmed
        case updatedAt = "updated_at"
        case network
    }
}

struct TonNativeBalance: Codable, Equatable {
    let balance: String
    let lastTxLt: String?
    let lastTxHash: String?

    private enum CodingKeys: String, CodingKey {
        case balance
        case lastTxLt = "last_tx_lt"
        case lastTxHash = "last_tx_hash"
    }
}

struct TonIndexerJettonBalance: Codable, Equatable {
    let master: String
    let wallet: String
    let balance: String
    let decimals: Int?
    let symbol: String?
}

struct TonBalancesResponse: Codable, Equatable {
    let address: String
    let tonRaw: String
    let ton: String
    let assets: [TonAssetBalance]
    let confirmed: Bool
    let updatedAt: Int64
    let network: String

    private enum CodingKeys: String, CodingKey {
        case address
        case tonRaw = "ton_raw"
        case ton
        case assets
        case confirmed
        case updatedAt = "updated_at"
        case network
    }
}

struct TonAssetBalance: Codable, Equatable {
    let kind: String
    let symbol: String?
    let address: String?
    let wallet: String?
    let balanceRaw: String
    let balance: String
    let decimals: Int

    private enum CodingKeys: String, CodingKey {
        case kind
        case symbol
        case address
        case wallet
        case balanceRaw = "balance_raw"
        case balance
        case decimals
    }
}

struct TonAccountStateResponse: Codable, Equatable {
    let address: String
    let balance: String
    let lastTxLt: String?
    let lastTxHash: String?
    let accountState: String?
    let codeBoc: String?
    let dataBoc: String?
    let updatedAt: Int64
}

struct TonJettonTransferPayloadResponse: Codable, Equatable {
    let customPayload: String?
    let stateInit: String?

    private enum CodingKeys: String, CodingKey {
        case customPayload = "custom_payload"
        case stateInit = "state_init"
    }
}

struct TonTransactionsResponse: Codable, Equatable {
    let page: Int
    let pageSize: Int
    let totalTxs: Int
    let totalPages: Int?
    let totalPagesMin: Int
    let historyComplete: Bool
    let txs: [TonTransactionEntry]
    let network: String

    private enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalTxs = "total_txs"
        case totalPages = "total_pages"
        case totalPagesMin = "total_pages_min"
        case historyComplete = "history_complete"
        case txs
        case network
    }
}

struct TonTransactionEntry: Codable, Equatable {
    let txId: String
    let utime: Int64
    let status: String
    let reason: String?
    let txType: String
    let inSource: String?
    let inValue: String?
    let outCount: Int
    let detail: [String: TonJSONValue]
    let kind: String
    let actions: [[String: TonJSONValue]]
    let lt: String
    let hash: String
    let inMessage: TonMessageSummary?
    let outMessages: [TonMessageSummary]
}

struct TonMessageSummary: Codable, Equatable {
    let source: String?
    let destination: String?
    let value: String?
    let op: Int64?
    let body: String?
}

struct TonSwapsResponse: Codable, Equatable {
    let address: String
    let swaps: [TonSwapExecution]
    let count: Int
    let network: String
}

struct TonSwapExecution: Codable, Equatable {
    let txId: String
    let lt: String
    let hash: String
    let utime: Int64
    let status: String
    let reason: String?
    let payToken: String?
    let receiveToken: String?
    let payAmount: String?
    let receiveAmount: String?
    let queryId: String?
    let executionType: String?
}

struct TonRunGetMethodRequest: Codable, Equatable {
    let address: String
    let method: String
    let stack: [[TonJSONValue]]
}

struct TonRunGetMethodsRequest: Codable, Equatable {
    let calls: [TonRunGetMethodRequest]
}

struct TonRunGetMethodResponse: Codable, Equatable {
    let exitCode: Int
    let gasUsed: Int64
    let stack: [[TonJSONValue]]

    private enum CodingKeys: String, CodingKey {
        case exitCode = "exit_code"
        case gasUsed = "gas_used"
        case stack
    }
}

struct TonRunGetMethodsResponse: Codable, Equatable {
    let results: [TonRunGetMethodBatchResult]
}

struct TonRunGetMethodBatchResult: Codable, Equatable {
    let ok: Bool
    let exitCode: Int?
    let gasUsed: Int64?
    let stack: [[TonJSONValue]]?
    let code: String?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case exitCode = "exit_code"
        case gasUsed = "gas_used"
        case stack
        case code
        case error
    }
}
