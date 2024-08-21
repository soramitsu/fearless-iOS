import Foundation
import BigInt
import SSFUtils

struct ZChainHistoryResponse: Decodable {
    let data: [ZChainHistoryElement]?
}

struct ZChainHistoryElement: Decodable {
    enum CodingKeys: String, CodingKey {
        case blockNumber = "bn"
        case timestamp = "ti"
        case hash = "h"
        case nonce = "n"
        case blockHash = "bi"
        case from = "f"
        case to = "t"
        case value = "v"
        case fee = "tf"
    }

    let blockNumber: UInt64?
    let timestamp: UInt64?
    let hash: String?
    let nonce: String?
    let blockHash: String?
    let from: ZchainDestination?
    let to: ZchainDestination?
    @StringCodable var value: BigUInt
    @StringCodable var fee: BigUInt

    var timestampInSeconds: Int64 {
        guard let timeStamp = timestamp else {
            return 0
        }

        return Int64(timeStamp)
    }
}

struct ZchainDestination: Decodable {
    enum CodingKeys: String, CodingKey {
        case address = "a"
    }

    let address: String
}
