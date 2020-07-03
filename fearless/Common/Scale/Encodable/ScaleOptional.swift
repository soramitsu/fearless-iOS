import Foundation

enum ScaleOptional<T: ScaleCodable> {
    case none
    case some(value: T)

    init(value: T?) {
        if let value = value {
            self = .some(value: value)
        } else {
            self = .none
        }
    }

    var value: T? {
        switch self {
        case .none:
            return nil
        case .some(let value):
            return value
        }
    }
}

enum ScaleOptionalDecodingError: Error {
    case invalidPrefix
}

extension ScaleOptional: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .none:
            scaleEncoder.appendRaw(data: Data([0]))
        case .some(let value):
            scaleEncoder.appendRaw(data: Data([1]))
            try value.encode(scaleEncoder: scaleEncoder)
        }
    }
}

extension ScaleOptional: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let mode = try scaleDecoder.read(count: 1)[0]
        try scaleDecoder.confirm(count: 1)

        switch mode {
        case 0:
            self = .none
        case 1:
            let value = try T.init(scaleDecoder: scaleDecoder)
            self = .some(value: value)
        default:
            throw ScaleOptionalDecodingError.invalidPrefix
        }
    }
}
