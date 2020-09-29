import Foundation
import IrohaCrypto
import BigInt
import FearlessUtils

protocol ExtrinsicFactoryProtocol {
    static func transferExtrinsic(_ address: String,
                                  amount: BigUInt,
                                  nonce: UInt32,
                                  genesisHash: Data,
                                  signer: IRSignatureCreatorProtocol) throws -> Data
}

struct ExtrinsicParameters {
    let nonce: UInt32
    let genesisHash: Data
    let specVersion: UInt32
    let transactionVersion: UInt32
}

struct ExtrinsicFactory {
    static let signatureVersion: UInt8 = 1
    static let extrinsicVersion: UInt8 = 132

    static func transferExtrinsic(from senderAccountId: Data,
                                  to receiverAccountId: Data,
                                  amount: BigUInt,
                                  additionalParameters: ExtrinsicParameters,
                                  signer: IRSignatureCreatorProtocol) throws -> Data {
        let transferCall = TransferCall(receiver: receiverAccountId,
                                        amount: amount)

        let callEncoder = ScaleEncoder()
        try transferCall.encode(scaleEncoder: callEncoder)
        let callArguments = callEncoder.encode()

        let call = Call(moduleIndex: 4, callIndex: 0, arguments: callArguments)

        let era = Era.immortal
        let tip = BigUInt(0)

        let payload = ExtrinsicPayload(call: call,
                                       era: era,
                                       nonce: additionalParameters.nonce,
                                       tip: tip,
                                       specVersion: additionalParameters.specVersion,
                                       transactionVersion: additionalParameters.transactionVersion,
                                       genesisHash: additionalParameters.genesisHash,
                                       blockHash: additionalParameters.genesisHash)

        let payloadEncoder = ScaleEncoder()
        try payload.encode(scaleEncoder: payloadEncoder)

        let signature = try signer.sign(payloadEncoder.encode())

        let transaction = Transaction(accountId: senderAccountId,
                                      signatureVersion: Self.signatureVersion,
                                      signature: signature.rawData(),
                                      era: era,
                                      nonce: additionalParameters.nonce,
                                      tip: tip)

        let extrinsic = Extrinsic(version: Self.extrinsicVersion,
                                  transaction: transaction,
                                  call: call)

        let extrinsicCoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicCoder)

        return extrinsicCoder.encode()
    }
}
