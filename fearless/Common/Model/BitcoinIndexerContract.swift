import Foundation

enum BitcoinIndexerRouteError: Error, Equatable {
    case invalidBaseURL
    case invalidAddress
    case invalidTxid
    case invalidTxHex
}

enum BitcoinIndexerNetwork: Equatable {
    case mainnet
    case testnet

    var defaultBaseURL: URL {
        switch self {
        case .mainnet:
            return UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL
        case .testnet:
            return UniversalWalletRegistry.bitcoinTestnetIndexerBaseURL
        }
    }
}

enum BitcoinIndexerRoutes {
    static let maxTxHexLength = 800_000

    static func addressURL(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL ?? network.defaultBaseURL.absoluteString))/address/\(normalizeAddress(address, network: network))")
    }

    static func utxosURL(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) throws -> URL {
        try makeURL("\(addressURL(address: address, network: network, baseURL: baseURL).absoluteString)/utxo")
    }

    static func transactionsURL(
        address: String,
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil,
        lastSeenTxid: String? = nil,
        mempool: Bool = false
    ) throws -> URL {
        let normalizedBaseURL = try normalizeBaseURL(baseURL ?? network.defaultBaseURL.absoluteString)
        let normalizedAddress = try normalizeAddress(address, network: network)
        let base = "\(normalizedBaseURL)/address/\(normalizedAddress)/txs"

        if mempool {
            return try makeURL("\(base)/mempool")
        }

        if let lastSeenTxid {
            return try makeURL("\(base)/chain/\(normalizeTxid(lastSeenTxid))")
        }

        return try makeURL(base)
    }

    static func feeEstimatesURL(
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL ?? network.defaultBaseURL.absoluteString))/fee-estimates")
    }

    static func broadcastTransactionURL(
        network: BitcoinIndexerNetwork = .mainnet,
        baseURL: String? = nil
    ) throws -> URL {
        try makeURL("\(normalizeBaseURL(baseURL ?? network.defaultBaseURL.absoluteString))/tx")
    }

    static func normalizeBroadcastTransactionBody(_ txHex: String) throws -> String {
        let normalized = txHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard
            normalized.count <= maxTxHexLength,
            normalized.range(of: "^(?:[0-9a-f]{2})+$", options: .regularExpression) != nil
        else {
            throw BitcoinIndexerRouteError.invalidTxHex
        }

        return normalized
    }

    static func normalizeBaseURL(_ baseURL: String) throws -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else {
            throw BitcoinIndexerRouteError.invalidBaseURL
        }

        let isLocal = host == "localhost" || host == "127.0.0.1"
        guard scheme == "https" || isLocal else {
            throw BitcoinIndexerRouteError.invalidBaseURL
        }

        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func normalizeAddress(_ address: String, network: BitcoinIndexerNetwork) throws -> String {
        let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern: String

        switch network {
        case .mainnet:
            pattern = "^bc1[ac-hj-np-z02-9]{11,90}$"
        case .testnet:
            pattern = "^tb1[ac-hj-np-z02-9]{11,90}$"
        }

        guard normalized.range(of: pattern, options: .regularExpression) != nil else {
            throw BitcoinIndexerRouteError.invalidAddress
        }

        return normalized
    }

    static func normalizeTxid(_ txid: String) throws -> String {
        let normalized = txid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw BitcoinIndexerRouteError.invalidTxid
        }

        return normalized
    }

    private static func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw BitcoinIndexerRouteError.invalidBaseURL
        }

        return url
    }
}

struct BitcoinEsploraStats: Codable, Equatable {
    let fundedTxoCount: Int
    let fundedTxoSum: Int64
    let spentTxoCount: Int
    let spentTxoSum: Int64
    let txCount: Int

    private enum CodingKeys: String, CodingKey {
        case fundedTxoCount = "funded_txo_count"
        case fundedTxoSum = "funded_txo_sum"
        case spentTxoCount = "spent_txo_count"
        case spentTxoSum = "spent_txo_sum"
        case txCount = "tx_count"
    }
}

struct BitcoinEsploraAddress: Codable, Equatable {
    let address: String
    let chainStats: BitcoinEsploraStats
    let mempoolStats: BitcoinEsploraStats

    var confirmedSats: Int64 {
        chainStats.fundedTxoSum - chainStats.spentTxoSum
    }

    var mempoolSats: Int64 {
        mempoolStats.fundedTxoSum - mempoolStats.spentTxoSum
    }

    var totalSats: Int64 {
        confirmedSats + mempoolSats
    }

    private enum CodingKeys: String, CodingKey {
        case address
        case chainStats = "chain_stats"
        case mempoolStats = "mempool_stats"
    }
}

struct BitcoinEsploraTxStatus: Codable, Equatable {
    let confirmed: Bool
    let blockHash: String?
    let blockHeight: Int64?
    let blockTime: Int64?

    private enum CodingKeys: String, CodingKey {
        case confirmed
        case blockHash = "block_hash"
        case blockHeight = "block_height"
        case blockTime = "block_time"
    }
}

struct BitcoinEsploraUtxo: Codable, Equatable {
    let txid: String
    let vout: Int64
    let value: Int64
    let status: BitcoinEsploraTxStatus
}

struct BitcoinEsploraTransaction: Codable, Equatable {
    let txid: String
    let status: BitcoinEsploraTxStatus
    let fee: Int64?
    let weight: Int64?
    let size: Int64?
    let version: Int64?
    let locktime: Int64?
    let vin: [BitcoinEsploraTransactionInput]
    let vout: [BitcoinEsploraTransactionOutput]

    init(
        txid: String,
        status: BitcoinEsploraTxStatus,
        fee: Int64? = nil,
        weight: Int64? = nil,
        size: Int64? = nil,
        version: Int64? = nil,
        locktime: Int64? = nil,
        vin: [BitcoinEsploraTransactionInput] = [],
        vout: [BitcoinEsploraTransactionOutput] = []
    ) {
        self.txid = txid
        self.status = status
        self.fee = fee
        self.weight = weight
        self.size = size
        self.version = version
        self.locktime = locktime
        self.vin = vin
        self.vout = vout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        txid = try container.decode(String.self, forKey: .txid)
        status = try container.decode(BitcoinEsploraTxStatus.self, forKey: .status)
        fee = try container.decodeIfPresent(Int64.self, forKey: .fee)
        weight = try container.decodeIfPresent(Int64.self, forKey: .weight)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        version = try container.decodeIfPresent(Int64.self, forKey: .version)
        locktime = try container.decodeIfPresent(Int64.self, forKey: .locktime)
        vin = try container.decodeIfPresent([BitcoinEsploraTransactionInput].self, forKey: .vin) ?? []
        vout = try container.decodeIfPresent([BitcoinEsploraTransactionOutput].self, forKey: .vout) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case txid
        case status
        case fee
        case weight
        case size
        case version
        case locktime
        case vin
        case vout
    }
}

struct BitcoinEsploraTransactionInput: Codable, Equatable {
    let prevout: BitcoinEsploraTransactionOutput?

    init(prevout: BitcoinEsploraTransactionOutput? = nil) {
        self.prevout = prevout
    }
}

struct BitcoinEsploraTransactionOutput: Codable, Equatable {
    let scriptPubKeyAddress: String?
    let value: Int64?

    init(scriptPubKeyAddress: String? = nil, value: Int64? = nil) {
        self.scriptPubKeyAddress = scriptPubKeyAddress
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scriptPubKeyAddress = try container.decodeIfPresent(String.self, forKey: .scriptPubKeyAddress)
        value = try? container.decodeIfPresent(Int64.self, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case scriptPubKeyAddress = "scriptpubkey_address"
        case value
    }
}
