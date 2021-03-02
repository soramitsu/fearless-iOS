import Foundation
import FearlessUtils
import BigInt

struct Extrinsic: ScaleCodable {
    let version: UInt8
    let transaction: Transaction?
    let call: Call

    init(version: UInt8, transaction: Transaction?, call: Call) {
        self.version = version
        self.transaction = transaction
        self.call = call
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let lengthValue = try BigUInt(scaleDecoder: scaleDecoder)
        let extrinsicLength = Int(lengthValue)

        let extrinsicData = try scaleDecoder.read(count: extrinsicLength)
        try scaleDecoder.confirm(count: extrinsicLength)

        let internalDecoder = try ScaleDecoder(data: extrinsicData)
        version = try UInt8(scaleDecoder: internalDecoder)

        if version >= ExtrinsicConstants.signedExtrinsicInitialVersion {
            transaction = try Transaction(scaleDecoder: internalDecoder)
        } else {
            transaction = nil
        }

        let moduleIndex = try UInt8(scaleDecoder: internalDecoder)
        let callIndex = try UInt8(scaleDecoder: internalDecoder)

        let arguments: Data?

        if internalDecoder.remained > 0 {
            arguments = try internalDecoder.read(count: internalDecoder.remained)
            try internalDecoder.confirm(count: internalDecoder.remained)
        } else {
            arguments = nil
        }

        call = Call(moduleIndex: moduleIndex, callIndex: callIndex, arguments: arguments)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        let internalEncoder = ScaleEncoder()
        try version.encode(scaleEncoder: internalEncoder)
        try transaction?.encode(scaleEncoder: internalEncoder)
        try call.moduleIndex.encode(scaleEncoder: internalEncoder)
        try call.callIndex.encode(scaleEncoder: internalEncoder)

        if let arguments = call.arguments {
            internalEncoder.appendRaw(data: arguments)
        }

        let encodedData = internalEncoder.encode()
        let encodedLength = BigUInt(encodedData.count)

        try encodedLength.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: encodedData)
    }
}

struct Transaction: ScaleCodable {
    let address: Multiaddress
    let signatureVersion: UInt8
    let signature: Data
    let era: Era
    let nonce: UInt32
    let tip: BigUInt

    init(address: Multiaddress,
         signatureVersion: UInt8,
         signature: Data,
         era: Era,
         nonce: UInt32,
         tip: BigUInt) {
        self.address = address
        self.signatureVersion = signatureVersion
        self.signature = signature
        self.era = era
        self.nonce = nonce
        self.tip = tip
    }

    init(scaleDecoder: ScaleDecoding) throws {
        address = try Multiaddress(scaleDecoder: scaleDecoder)
        signatureVersion = try UInt8(scaleDecoder: scaleDecoder)

        guard let cryptoType = CryptoType(version: signatureVersion) else {
            throw ExtrinsicCodingError.unsupportedSignatureVersion
        }

        signature = try scaleDecoder.readAndConfirm(count: cryptoType.signatureLength)

        era = try Era(scaleDecoder: scaleDecoder)

        let nonceValue = try BigUInt(scaleDecoder: scaleDecoder)
        nonce = UInt32(nonceValue)

        tip = try BigUInt(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try address.encode(scaleEncoder: scaleEncoder)
        try signatureVersion.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: signature)
        try era.encode(scaleEncoder: scaleEncoder)
        try BigUInt(nonce).encode(scaleEncoder: scaleEncoder)
        try tip.encode(scaleEncoder: scaleEncoder)
    }
}
