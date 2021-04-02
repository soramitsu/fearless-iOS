import Foundation
import IrohaCrypto
import BigInt
import FearlessUtils

struct ExtrinsicFactory: ExtrinsicFactoryProtocol {
    static func transferExtrinsic(
        from senderAccountId: Data,
        to receiverAccountId: Data,
        amount: BigUInt,
        additionalParameters: ExtrinsicParameters,
        signer: IRSignatureCreatorProtocol
    ) throws -> Data {
        let transferCall = TransferCall(
            receiver: .accountId(receiverAccountId),
            amount: amount
        )

        let callEncoder = ScaleEncoder()
        try transferCall.encode(scaleEncoder: callEncoder)
        let callArguments = callEncoder.encode()

        let call = Call(
            moduleIndex: additionalParameters.moduleIndex,
            callIndex: additionalParameters.callIndex,
            arguments: callArguments
        )

        let era = Era.immortal
        let tip = BigUInt(0)

        let payload = ExtrinsicPayload(
            call: call,
            era: era,
            nonce: additionalParameters.nonce,
            tip: tip,
            specVersion: additionalParameters.specVersion,
            transactionVersion: additionalParameters.transactionVersion,
            genesisHash: additionalParameters.genesisHash,
            blockHash: additionalParameters.genesisHash
        )

        let payloadEncoder = ScaleEncoder()
        try payload.encode(scaleEncoder: payloadEncoder)

        let payloadData = payloadEncoder.encode()

        let signature = try signer.sign(payloadData)

        let transaction = Transaction(
            address: .accountId(senderAccountId),
            signatureVersion: additionalParameters.signatureVersion,
            signature: signature.rawData(),
            era: era,
            nonce: additionalParameters.nonce,
            tip: tip
        )

        let extrinsic = Extrinsic(
            version: ExtrinsicConstants.extrinsicVersion,
            transaction: transaction,
            call: call
        )

        let extrinsicCoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: extrinsicCoder)

        return extrinsicCoder.encode()
    }
}
