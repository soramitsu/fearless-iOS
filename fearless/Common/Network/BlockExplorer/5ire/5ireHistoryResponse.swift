import Foundation
import BigInt
import SSFUtils

struct FireHistoryResponse: Decodable {
    let error: Bool?
    let message: String?
    let data: FireHistoryResponseData?
}

struct FireHistoryResponseData: Decodable {
    let count: UInt32
    let transactions: [FireHistoryTransaction]
}

struct FireHistoryTransaction: Decodable {
    let blockNumber: String?
    let createdAt: String?
    let hash: String?
    let nonce: String?
    let blockHash: String?
    let fromAddress: String?
    let toAddress: String?
    @StringCodable var value: BigUInt
    @StringCodable var gas: BigUInt
    @StringCodable var gasPrice: BigUInt

    var timestampInSeconds: Int64 {
        guard let dateString = createdAt else {
            return 0
        }
        return DateFormatter.networkTimestampInSeconds(from: dateString, using: DateFormatter.alchemyDate)
    }
}
