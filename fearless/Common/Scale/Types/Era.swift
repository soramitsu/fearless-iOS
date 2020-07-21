import Foundation

enum Era {
    case immortal
    case mortal
}

enum EraCodingError: Error {
    case undefinedValue
    case unsupported
}

extension Era: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let typeValue = try UInt8(scaleDecoder: scaleDecoder)

        switch typeValue {
        case 0:
            self = .immortal
        case 1:
            try scaleDecoder.confirm(count: 1)

            self = .mortal
        default:
            throw EraCodingError.undefinedValue
        }
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .immortal:
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
        default:
            throw EraCodingError.unsupported
        }
    }
}
