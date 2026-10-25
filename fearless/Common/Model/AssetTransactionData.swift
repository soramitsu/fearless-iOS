import Foundation

enum AssetTransactionStatus: String, Codable {
    case pending = "PENDING"
    case commited = "COMMITTED"
    case rejected = "REJECTED"
}

struct AssetTransactionData: Codable, Equatable {
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

    let transactionId: String
    let status: AssetTransactionStatus
    let assetId: String
    let peerId: String
    let peerFirstName: String?
    let peerLastName: String?
    let peerName: String?
    let details: String
    let amount: AmountDecimal
    let fees: [AssetTransactionFee]
    let timestamp: Int64
    let type: String
    let reason: String?
    let context: [String: String]?

    init(
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

struct AssetTransactionPageData: Codable, Equatable {
    let transactions: [AssetTransactionData]
    let context: PaginationContext?

    init(
        transactions: [AssetTransactionData],
        context: PaginationContext? = nil
    ) {
        self.transactions = transactions
        self.context = context
    }
}
