import Foundation
import FearlessUtils

struct SlashingSpans: ScaleCodable {
    let spanIndex: UInt32
    let lastStart: UInt32
    let lastNonzeroSlash: UInt32
    let prior: [UInt32]

    init(scaleDecoder: ScaleDecoding) throws {
        spanIndex = try UInt32(scaleDecoder: scaleDecoder)
        lastStart = try UInt32(scaleDecoder: scaleDecoder)
        lastNonzeroSlash = try UInt32(scaleDecoder: scaleDecoder)
        prior = try [UInt32](scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try spanIndex.encode(scaleEncoder: scaleEncoder)
        try lastStart.encode(scaleEncoder: scaleEncoder)
        try lastNonzeroSlash.encode(scaleEncoder: scaleEncoder)
        try prior.encode(scaleEncoder: scaleEncoder)
    }
}
