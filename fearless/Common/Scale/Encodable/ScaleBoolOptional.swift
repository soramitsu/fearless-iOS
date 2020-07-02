import Foundation

enum ScaleBoolOptional {
    case none
    case valueTrue
    case valueFalse

    init(value: Bool?) {
        if let value = value {
            self = value ? .valueTrue : .valueFalse
        } else {
            self = .none
        }
    }

    var value: Bool? {
        switch self {
        case .none:
            return nil
        case .valueTrue:
            return true
        case .valueFalse:
            return false
        }
    }
}

enum ScaleBoolOptionalDecodingError: Error {
    case invalidPrefix
}

extension ScaleBoolOptional: ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .none:
            scaleEncoder.appendRaw(data: Data([0]))
        case .valueFalse:
            scaleEncoder.appendRaw(data: Data([1]))
        case .valueTrue:
            scaleEncoder.appendRaw(data: Data([2]))
        }
    }
}

extension ScaleBoolOptional: ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let mode = try scaleDecoder.read(count: 1)[0]
        try scaleDecoder.confirm(count: 1)

        switch mode {
        case 0:
            self = .none
        case 1:
            self = .valueFalse
        case 2:
            self = .valueTrue
        default:
            throw ScaleOptionalDecodingError.invalidPrefix
        }
    }
}
