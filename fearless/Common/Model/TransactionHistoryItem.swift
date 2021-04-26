import Foundation
import RobinHood

struct TransactionHistoryItem: Codable {
    enum CodingKeys: String, CodingKey {
        case sender
        case receiver
        case status
        case txHash
        case timestamp
        case fee
        case blockNumber
        case txIndex
        case callPath
        case call
    }

    enum Status: Int16, Codable {
        case pending
        case success
        case failed
    }

    let sender: String
    let receiver: String?
    let status: Status
    let txHash: String
    let timestamp: Int64
    let fee: String
    let blockNumber: UInt64?
    let txIndex: UInt16?
    let callPath: CallCodingPath
    let call: Data?
}

extension TransactionHistoryItem: Identifiable {
    var identifier: String { txHash }
}
