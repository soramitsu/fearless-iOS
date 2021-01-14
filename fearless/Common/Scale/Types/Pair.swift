import Foundation
import FearlessUtils

struct Pair<F: ScaleCodable, S: ScaleCodable>: ScaleCodable {
    let first: F
    let second: S

    init(first: F, second: S) {
        self.first = first
        self.second = second
    }

    init(scaleDecoder: ScaleDecoding) throws {
        first = try F(scaleDecoder: scaleDecoder)
        second = try S(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try first.encode(scaleEncoder: scaleEncoder)
        try second.encode(scaleEncoder: scaleEncoder)
    }
}
