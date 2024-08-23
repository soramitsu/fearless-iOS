import Foundation
import BigInt
import SSFUtils

struct ViscanHistoryResponse: Decodable {
    let data: [ViscanHistoryElement]?
}

struct ViscanHistoryElement: Decodable {
    let blockNumber: UInt64?
    let timestamp: UInt64?
    let hash: String?
    let nonce: UInt32?
    let blockHash: String?
    let from: String?
    let to: String?
    let contractAddress: String?
    @StringCodable var value: BigUInt
    var fee: Decimal

    var timestampInSeconds: Int64 {
        guard let timeStamp = timestamp else {
            return 0
        }

        return Int64(timeStamp)
    }
}
