import Foundation
import FearlessUtils
import BigInt

struct TransferCall: ScaleCodable {
    let receiver: Data
    let amount: BigUInt

    init(receiver: Data, amount: BigUInt) {
        self.receiver = receiver
        self.amount = amount
    }

    init(scaleDecoder: ScaleDecoding) throws {
        receiver = try scaleDecoder.readAndConfirm(count: 32)
        amount = try BigUInt(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: receiver)
        try amount.encode(scaleEncoder: scaleEncoder)
    }
}
