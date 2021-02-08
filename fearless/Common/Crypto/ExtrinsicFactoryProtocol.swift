import Foundation
import BigInt
import IrohaCrypto

protocol ExtrinsicFactoryProtocol {
    static func transferExtrinsic(from senderAccountId: Data,
                                  to receiverAccountId: Data,
                                  amount: BigUInt,
                                  additionalParameters: ExtrinsicParameters,
                                  signer: IRSignatureCreatorProtocol) throws -> Data
}

struct ExtrinsicParameters {
    let nonce: UInt32
    let genesisHash: Data
    let specVersion: UInt32
    let transactionVersion: UInt32
    let signatureVersion: UInt8
    let moduleIndex: UInt8
    let callIndex: UInt8
}
