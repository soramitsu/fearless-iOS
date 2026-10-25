import Foundation

public enum ScaleOption<T: ScaleCodable> {
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
        case let .some(value):
            return value
        }
    }
}

extension ScaleOption: Equatable where T: Equatable {}

public enum ScaleOptionDecodingError: Error {
    case invalidPrefix
}

extension ScaleOption: ScaleEncodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .none:
            scaleEncoder.appendRaw(data: Data([0]))
        case let .some(value):
            scaleEncoder.appendRaw(data: Data([1]))
            try value.encode(scaleEncoder: scaleEncoder)
        }
    }
}

extension ScaleOption: ScaleDecodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        let mode = try scaleDecoder.read(count: 1)[0]
        try scaleDecoder.confirm(count: 1)

        switch mode {
        case 0:
            self = .none
        case 1:
            let value = try T(scaleDecoder: scaleDecoder)
            self = .some(value: value)
        default:
            throw ScaleOptionDecodingError.invalidPrefix
        }
    }
}
