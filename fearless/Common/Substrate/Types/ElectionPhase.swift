import Foundation
import FearlessUtils

enum ElectionPhase: ScaleDecodable {
    case off
    case signed
    case unsigned(isOpen: Bool, blockNumber: UInt32)

    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        switch type {
        case 0:
            self = .off
        case 1:
            self = .signed
        case 2:
            let isOpen = try Bool(scaleDecoder: scaleDecoder)
            let blockNumber = try UInt32(scaleDecoder: scaleDecoder)

            self = .unsigned(isOpen: isOpen, blockNumber: blockNumber)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }
}
