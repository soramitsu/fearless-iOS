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
    @StringCodable var value: BigUInt
    @StringCodable var gas: BigUInt
    @StringCodable var gasPrice: BigUInt
    @StringCodable var gasUsed: BigUInt

    var timestampInSeconds: Int64 {
        guard let timeStamp = timeStamp else {
            return 0
        }

        return Int64(timeStamp) ?? 0
    }
}
