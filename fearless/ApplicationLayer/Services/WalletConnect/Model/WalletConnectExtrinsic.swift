import Foundation
import SSFUtils
import BigInt
import SSFModels

struct WalletConnectExtrinsic: Codable {
    let address: String
    let blockHash: String
    @StringCodable var blockNumber: BigUInt
    let era: Era
    let genesisHash: String
    let method: WalletConnectPolkadotCall
    @StringCodable var nonce: BigUInt
    let specVersion: UInt32
    @StringCodable var tip: BigUInt
    let transactionVersion: UInt32
    let signedExtensions: [String]
    let version: UInt
}

enum WalletConnectPolkadotCall: Codable {
    case raw(bytes: Data)
    case callable(value: RuntimeCall<JSON>)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .raw(bytes):
            try bytes.toHex(includePrefix: true).encode(to: encoder)
        case let .callable(value):
            try value.encode(to: encoder)
        }
    }
}
