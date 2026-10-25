import Foundation

public enum ScaleBoolOption: CaseIterable {
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

public enum ScaleBoolOptionalDecodingError: Error {
    case invalidPrefix
}

extension ScaleBoolOption: ScaleEncodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
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

extension ScaleBoolOption: ScaleDecodable {
    public init(scaleDecoder: ScaleDecoding) throws {
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
            throw ScaleOptionDecodingError.invalidPrefix
        }
    }
}
