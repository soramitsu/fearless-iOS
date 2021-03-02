import Foundation
import FearlessUtils
import BigInt

struct TransferCall: ScaleCodable {
    let receiver: Multiaddress
    let amount: BigUInt

    init(receiver: Multiaddress, amount: BigUInt) {
        self.receiver = receiver
        self.amount = amount
    }

    init(scaleDecoder: ScaleDecoding) throws {
        receiver = try Multiaddress(scaleDecoder: scaleDecoder)
        amount = try BigUInt(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try receiver.encode(scaleEncoder: scaleEncoder)
        try amount.encode(scaleEncoder: scaleEncoder)
    }
}
