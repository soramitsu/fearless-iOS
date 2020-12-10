import Foundation
import FearlessUtils

struct Nominations: ScaleCodable {
    let targets: [AccountId]
    let submittedInEra: UInt32
    let suppressed: Bool

    init(scaleDecoder: ScaleDecoding) throws {
        targets = try [AccountId](scaleDecoder: scaleDecoder)
        submittedInEra = try UInt32(scaleDecoder: scaleDecoder)
        suppressed = try Bool(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try targets.encode(scaleEncoder: scaleEncoder)
        try submittedInEra.encode(scaleEncoder: scaleEncoder)
        try suppressed.encode(scaleEncoder: scaleEncoder)
    }
}
