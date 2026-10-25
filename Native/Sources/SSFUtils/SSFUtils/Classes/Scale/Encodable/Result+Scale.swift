import Foundation

extension Result: ScaleCodable where Success: ScaleCodable, Failure: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case let .success(value):
            scaleEncoder.appendRaw(data: Data([0]))
            try value.encode(scaleEncoder: scaleEncoder)
        case let .failure(error):
            scaleEncoder.appendRaw(data: Data([1]))
            try error.encode(scaleEncoder: scaleEncoder)
        }
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let mode = try scaleDecoder.read(count: 1)[0]
        try scaleDecoder.confirm(count: 1)

        switch mode {
        case 0:
            let value = try Success(scaleDecoder: scaleDecoder)
            self = .success(value)
        case 1:
            let error = try Failure(scaleDecoder: scaleDecoder)
            self = .failure(error)
        default:
            throw ScaleOptionDecodingError.invalidPrefix
        }
    }
}
