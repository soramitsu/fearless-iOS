import Foundation

enum SolanaIndexerRouteError: Error, Equatable {
    case invalidBaseURL
    case invalidWallet
    case invalidMint
    case invalidMints
    case invalidBefore
    case invalidLimit
}

enum SolanaIndexerRoutes {
    static let defaultLimit = 100
    static let maxLimit = 250
    static let maxMetadataBatchSize = 100

    static func serviceInfoURL(
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/service-info")
    }

    static func balancesURL(
        wallet: String,
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        try accountURL(baseURL: baseURL, wallet: wallet, section: "balances")
    }

    static func assetsURL(
        wallet: String,
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        try accountURL(baseURL: baseURL, wallet: wallet, section: "assets")
    }

    static func stateURL(
        wallet: String,
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        try accountURL(baseURL: baseURL, wallet: wallet, section: "state")
    }

    static func transactionsURL(
        wallet: String,
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString,
        before: String? = nil,
        limit: Int = defaultLimit
    ) throws -> URL {
        guard (1 ... maxLimit).contains(limit) else {
            throw SolanaIndexerRouteError.invalidLimit
        }

        let wallet = try normalizePublicKey(wallet, error: .invalidWallet)
        guard var components = URLComponents(string: "\(try normalizeBaseURL(baseURL))/api/indexer/v1/accounts/\(wallet)/txs") else {
            throw SolanaIndexerRouteError.invalidBaseURL
        }

        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            queryItems.append(URLQueryItem(name: "before", value: try normalizeSignature(before)))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw SolanaIndexerRouteError.invalidBaseURL
        }

        return url
    }

    static func tokenMetadataURL(
        mint: String,
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        let mint = try normalizePublicKey(mint, error: .invalidMint)
        return try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/tokens/\(mint)/metadata")
    }

    static func tokenMetadataBatchURL(
        baseURL: String = UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString
    ) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/tokens/metadata")
    }

    static func tokenMetadataBatchRequest(mints: [String]) throws -> SolanaTokenMetadataBatchRequest {
        guard !mints.isEmpty, mints.count <= maxMetadataBatchSize else {
            throw SolanaIndexerRouteError.invalidMints
        }

        return SolanaTokenMetadataBatchRequest(
            mints: try mints.map { try normalizePublicKey($0, error: .invalidMint) }
        )
    }

    static func normalizeBaseURL(_ baseURL: String) throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else {
            throw SolanaIndexerRouteError.invalidBaseURL
        }

        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw SolanaIndexerRouteError.invalidBaseURL
        }

        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func accountURL(baseURL: String, wallet: String, section: String) throws -> URL {
        let wallet = try normalizePublicKey(wallet, error: .invalidWallet)
        return try makeURL("\(normalizeBaseURL(baseURL))/api/indexer/v1/accounts/\(wallet)/\(section)")
    }

    private static func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw SolanaIndexerRouteError.invalidBaseURL
        }

        return url
    }

    private static func normalizePublicKey(_ value: String, error: SolanaIndexerRouteError) throws -> String {
        guard value.range(of: "^[1-9A-HJ-NP-Za-km-z]{32,44}$", options: .regularExpression) != nil else {
            throw error
        }

        return value
    }

    private static func normalizeSignature(_ value: String) throws -> String {
        guard value.range(of: "^[1-9A-HJ-NP-Za-km-z]{64,128}$", options: .regularExpression) != nil else {
            throw SolanaIndexerRouteError.invalidBefore
        }

        return value
    }
}

struct SolanaIndexerServiceInfo: Codable, Equatable {
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

    var isExpectedSIServiceInfo: Bool {
        schemaVersion == 1 &&
            serviceId == "si.soramitsu.io" &&
            ecosystem == "solana" &&
            chainId == "solana:mainnet" &&
            publicBaseUrl == "https://si.soramitsu.io" &&
            readOnly
    }
}

struct SolanaNativeBalance: Codable, Equatable {
    let type: String
    let mint: String
    let lamports: String
    let decimals: Int
    let uiAmountString: String
}

struct SolanaTokenBalance: Codable, Equatable {
    let type: String
    let accountAddress: String
    let mint: String
    let owner: String
    let program: String
    let programId: String
    let amount: String
    let decimals: Int
    let uiAmountString: String
    let state: String?
    let isNative: Bool
    let delegatedAmount: String?
    let rentExemptReserve: String?
}

struct SolanaWalletBalancesResponse: Codable, Equatable {
    let wallet: String
    let native: SolanaNativeBalance
    let tokens: [SolanaTokenBalance]
    let total: Int
    let syncedAt: Int64
}

struct SolanaWalletAsset: Codable, Equatable {
    let type: String
    let mint: String
    let lamports: String?
    let accountAddress: String?
    let owner: String?
    let program: String?
    let programId: String?
    let amount: String?
    let decimals: Int
    let uiAmountString: String
    let state: String?
    let isNative: Bool?
    let delegatedAmount: String?
    let rentExemptReserve: String?
}

struct SolanaWalletAssetsResponse: Codable, Equatable {
    let wallet: String
    let assets: [SolanaWalletAsset]
    let total: Int
    let syncedAt: Int64
}

struct SolanaWalletStateResponse: Codable, Equatable {
    let wallet: String
    let exists: Bool
    let lamports: String
    let owner: String?
    let executable: Bool
    let rentEpoch: String?
    let dataLength: Int
    let syncedAt: Int64
}

struct SolanaTokenBalanceChange: Codable, Equatable {
    let mint: String
    let preAmount: String
    let postAmount: String
    let amountDelta: String
    let decimals: Int
    let uiAmountDeltaString: String
}

struct SolanaWalletTransactionRecord: Codable, Equatable {
    let signature: String
    let slot: Int64
    let timestamp: Int64
    let status: String
    let feeLamports: String?
    let nativeBalanceChangeLamports: String?
    let tokenBalanceChanges: [SolanaTokenBalanceChange]
    let programIds: [String]
    let solswapRoute: String?
}

struct SolanaWalletTransactionsResponse: Codable, Equatable {
    let wallet: String
    let before: String?
    let nextBefore: String?
    let limit: Int
    let total: Int
    let syncedAt: Int64
    let transactions: [SolanaWalletTransactionRecord]
}

struct SolanaTokenMetadata: Codable, Equatable {
    let mint: String
    let exists: Bool
    let program: String
    let programId: String?
    let extensions: [String]?
    let transferFeeConfig: SolanaTokenTransferFeeConfig?
    let transferHook: SolanaTokenTransferHook?
    let decimals: Int?
    let supply: String?
    let uiSupplyString: String?
    let mintAuthority: String?
    let freezeAuthority: String?
    let isInitialized: Bool?
    let name: String?
    let symbol: String?
    let uri: String?
    let syncedAt: Int64
}

struct SolanaTokenTransferFee: Codable, Equatable {
    let epoch: String?
    let maximumFee: String?
    let transferFeeBasisPoints: Int?
}

struct SolanaTokenTransferFeeConfig: Codable, Equatable {
    let transferFeeConfigAuthority: String?
    let withdrawWithheldAuthority: String?
    let withheldAmount: String?
    let olderTransferFee: SolanaTokenTransferFee?
    let newerTransferFee: SolanaTokenTransferFee?
}

struct SolanaTokenTransferHook: Codable, Equatable {
    let authority: String?
    let programId: String?
    let extraAccountMetasAddress: String?
}

struct SolanaTokenMetadataBatchRequest: Codable, Equatable {
    let mints: [String]
}

struct SolanaTokenMetadataBatchResponse: Codable, Equatable {
    let total: Int
    let syncedAt: Int64
    let tokens: [SolanaTokenMetadata]
}
