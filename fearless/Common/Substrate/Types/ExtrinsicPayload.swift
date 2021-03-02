import Foundation
import FearlessUtils
import BigInt

struct ExtrinsicPayload: ScaleEncodable {
    let call: Call
    let era: Era
    let nonce: UInt32
    let tip: BigUInt
    let specVersion: UInt32
    let transactionVersion: UInt32
    let genesisHash: Data
    let blockHash: Data

    func encode(scaleEncoder: ScaleEncoding) throws {
        try call.moduleIndex.encode(scaleEncoder: scaleEncoder)
        try call.callIndex.encode(scaleEncoder: scaleEncoder)

        if let arguments = call.arguments {
            scaleEncoder.appendRaw(data: arguments)
        }

        try era.encode(scaleEncoder: scaleEncoder)
        try BigUInt(nonce).encode(scaleEncoder: scaleEncoder)
        try tip.encode(scaleEncoder: scaleEncoder)
        try specVersion.encode(scaleEncoder: scaleEncoder)
        try transactionVersion.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: genesisHash)
        scaleEncoder.appendRaw(data: blockHash)
    }
}
