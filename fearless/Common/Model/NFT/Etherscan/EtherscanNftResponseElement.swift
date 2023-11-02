import Foundation
import SSFModels

struct NFTHistoryObject: Decodable, Equatable, Hashable {
    let chain: ChainModel
    let metadata: EtherscanNftResponseElement
}

struct EtherscanNftResponseElement: Decodable, Equatable, Hashable {
    let blockNumber: String?
    let timeStamp: String?
    let hash: String?
    let nonce: String?
    let blockHash: String?
    let from: String?
    let contractAddress: String?
    let to: String?
    let tokenID: String?
    let tokenName: String?
    let tokenSymbol: String?
    let tokenDecimal: String?
    let transactionIndex: String?
    let gas: String?
    let gasPrice: String?
    let gasUsed: String?
    let cumulativeGasUsed: String?
    let input: String?
    let confirmations: String?

    var date: Date {
        guard let timeStamp = timeStamp else {
            return Date()
        }

        guard let timestampValue = TimeInterval(timeStamp) else {
            return Date()
        }

        return Date(timeIntervalSince1970: timestampValue)
    }
}
