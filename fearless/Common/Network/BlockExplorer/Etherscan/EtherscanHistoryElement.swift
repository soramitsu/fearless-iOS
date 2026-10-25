import Foundation
import BigInt
import SSFUtils

struct EtherscanHistoryElement: Decodable {
    let blockNumber: String?
    let timeStamp: String?
    let hash: String?
    let nonce: String?
    let blockHash: String?
    let from: String?
    let to: String?
    let contractAddress: String?
    let isError: String?
    let txReceiptStatus: String?
    @StringCodable var value: BigUInt
    @StringCodable var gas: BigUInt
    @StringCodable var gasPrice: BigUInt
    @StringCodable var gasUsed: BigUInt

    private enum CodingKeys: String, CodingKey {
        case blockNumber
        case timeStamp
        case hash
        case nonce
        case blockHash
        case from
        case to
        case contractAddress
        case isError
        case txReceiptStatus = "txreceipt_status"
        case value
        case gas
        case gasPrice
        case gasUsed
    }

    var timestampInSeconds: Int64 {
        guard let timeStamp = timeStamp else {
            return 0
        }

        return Int64(timeStamp) ?? 0
    }

    /// `isError` covers execution failures; `txreceipt_status` is "0" for a failed receipt
    /// and empty for transactions mined before Byzantium.
    var isFailed: Bool {
        isError == "1" || txReceiptStatus == "0"
    }
}
