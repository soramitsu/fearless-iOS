import Foundation
import RobinHood

struct TransactionHistoryItem: Codable {
    enum CodingKeys: String, CodingKey {
        case sender
        case receiver
        case status
        case txHash
        case timestamp
        case amount
        case fee
        case blockNumber
        case txIndex
    }

    enum Status: Int16, Codable {
        case pending
        case success
        case failed
    }

    let sender: String
    let receiver: String
    let status: Status
    let txHash: String
    let timestamp: Int64
    let amount: String
    let fee: String
    let blockNumber: Int64?
    let txIndex: Int16?
}

extension TransactionHistoryItem: Identifiable {
    var identifier: String { txHash }
}
