import Foundation

enum ScaleBoolDecodingError: Error {
    case invalidValue
}

extension Bool: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        if self {
            scaleEncoder.appendRaw(data: Data([1]))
        } else {
            scaleEncoder.appendRaw(data: Data([0]))
        }
    }
}

extension Bool: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let value = try scaleDecoder.read(count: 1)[0]

        switch value {
        case 0:
            self = false
        case 1:
            self = true
        default:
            throw ScaleBoolDecodingError.invalidValue
        }

        try scaleDecoder.confirm(count: 1)
    }
}
