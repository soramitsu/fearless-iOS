import Foundation

public enum AssetTransactionStatus: String, Codable {
    case pending = "PENDING"
    case commited = "COMMITTED"
    case rejected = "REJECTED"
}

public struct AssetTransactionData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case transactionId
        case status
        case assetId
        case peerId
        case peerName
        case peerFirstName
        case peerLastName
        case details
        case amount
        case fees
        case timestamp
        case type
        case reason
        case context
    }

    public let transactionId: String
    public let status: AssetTransactionStatus
    public let assetId: String
    public let peerId: String
    public let peerFirstName: String?
    public let peerLastName: String?
    public let peerName: String?
    public let details: String
    public let amount: AmountDecimal
    public let fees: [AssetTransactionFee]
    public let timestamp: Int64
    public let type: String
    public let reason: String?
    public let context: [String: String]?

    public init(
        transactionId: String,
        status: AssetTransactionStatus,
        assetId: String,
        peerId: String,
        peerFirstName: String?,
        peerLastName: String?,
        peerName: String?,
        details: String,
        amount: AmountDecimal,
        fees: [AssetTransactionFee],
        timestamp: Int64,
        type: String,
        reason: String?,
        context: [String: String]?
    ) {
        self.transactionId = transactionId
        self.status = status
        self.assetId = assetId
        self.peerId = peerId
        self.peerFirstName = peerFirstName
        self.peerLastName = peerLastName
        self.peerName = peerName
        self.details = details
        self.amount = amount
        self.fees = fees
        self.timestamp = timestamp
        self.type = type
        self.reason = reason
        self.context = context
    }
}

public struct AssetTransactionPageData: Codable, Equatable {
    public let transactions: [AssetTransactionData]
    public let context: PaginationContext?

    public init(
        transactions: [AssetTransactionData],
        context: PaginationContext? = nil
    ) {
        self.transactions = transactions
        self.context = context
    }
}
