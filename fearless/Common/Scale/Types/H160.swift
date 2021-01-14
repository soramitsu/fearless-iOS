import Foundation
import FearlessUtils

struct H160: ScaleCodable, Equatable {
    let value: Data

    init(scaleDecoder: ScaleDecoding) throws {
        value = try scaleDecoder.readAndConfirm(count: 20)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: value)
    }
}
