import Foundation
import FearlessUtils
import BigInt

struct IndividualExposure: ScaleCodable {
    let accoundId: AccountId
    let value: BigUInt

    init(scaleDecoder: ScaleDecoding) throws {
        accoundId = try AccountId(scaleDecoder: scaleDecoder)
        value = try BigUInt(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try accoundId.encode(scaleEncoder: scaleEncoder)
        try value.encode(scaleEncoder: scaleEncoder)
    }
}

struct Exposure: ScaleCodable {
    let total: BigUInt
    let own: BigUInt
    let other: [IndividualExposure]

    init(scaleDecoder: ScaleDecoding) throws {
        total = try BigUInt(scaleDecoder: scaleDecoder)
        own = try BigUInt(scaleDecoder: scaleDecoder)
        other = try [IndividualExposure](scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try total.encode(scaleEncoder: scaleEncoder)
        try own.encode(scaleEncoder: scaleEncoder)
        try other.encode(scaleEncoder: scaleEncoder)
    }
}
