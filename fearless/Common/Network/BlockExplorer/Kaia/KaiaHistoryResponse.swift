import Foundation
import BigInt
import SSFUtils

struct KaiaHistoryResponse: Decodable {
    let success: Bool?
    let code: Int?
    let result: [KaiaHistoryTransaction]?
}

struct KaiaHistoryTransaction: Decodable {
    let blockNumber: UInt64?
    let createdAt: UInt64?
    let txHash: String?
    let nonce: String?
    let blockHash: String?
    let fromAddress: String?
    let toAddress: String?
    @StringCodable var amount: BigUInt
    @StringCodable var txFee: BigUInt

    var timestampInSeconds: Int64 {
        guard let timeStamp = createdAt else {
            return 0
        }

        return Int64(timeStamp)
    }
}
