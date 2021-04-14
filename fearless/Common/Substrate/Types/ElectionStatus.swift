import Foundation
import FearlessUtils

enum ElectionStatus: Decodable, Equatable, ScaleDecodable {
    static let closeField = "Close"
    static let openField = "Open"

    case close
    case open(blockNumber: UInt32)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.closeField:
            self = .close
        case Self.openField:
            let blockNumber = try container.decode(StringScaleMapper<UInt32>.self).value
            self = .open(blockNumber: blockNumber)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected election status"
            )
        }
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let type = try UInt8(scaleDecoder: scaleDecoder)

        switch type {
        case 0:
            self = .close
        case 1:
            let blockNumber = try UInt32(scaleDecoder: scaleDecoder)
            self = .open(blockNumber: blockNumber)
        default:
            throw ScaleCodingError.unexpectedDecodedValue
        }
    }
}

extension ElectionStatus {
    init(phase: ElectionPhase) {
        switch phase {
        case .off:
            self = .close
        case .signed:
            self = .open(blockNumber: 0)
        case let .unsigned(isOpen, blockNumber):
            if isOpen {
                self = .open(blockNumber: blockNumber)
            } else {
                self = .close
            }
        }
    }
}
