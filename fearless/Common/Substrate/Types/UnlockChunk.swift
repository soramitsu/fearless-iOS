import Foundation
import FearlessUtils
import BigInt

struct UnlockChunk: ScaleCodable {
    let value: BigUInt
    let era: BigUInt

    init(scaleDecoder: ScaleDecoding) throws {
        value = try BigUInt(scaleDecoder: scaleDecoder)
        era = try BigUInt(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try value.encode(scaleEncoder: scaleEncoder)
        try era.encode(scaleEncoder: scaleEncoder)
    }
}
