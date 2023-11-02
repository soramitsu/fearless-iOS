import Foundation

struct WalletConnectPolkadotTransaction: Codable {
    let address: String
    let transactionPayload: TransactionPayload
}

struct TransactionPayload: Codable {
    let address: String
    let blockHash: String
    let blockNumber: String
    let era: String
    let genesisHash: String
    let method: String
    let nonce: String
    let signedExtensions: [String]
    let specVersion: String
    let tip: String
    let transactionVersion: String
    let version: UInt
}
