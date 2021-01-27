import Foundation
import FearlessUtils
import BigInt

struct ValidatorPrefs: ScaleDecodable {
    let commission: BigUInt

    init(scaleDecoder: ScaleDecoding) throws {
        commission = try BigUInt(scaleDecoder: scaleDecoder)
    }
}
