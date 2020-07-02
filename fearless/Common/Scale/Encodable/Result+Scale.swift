import Foundation

extension Result: ScaleCodable where Success: ScaleCodable, Failure: ScaleCodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .success(let value):
            scaleEncoder.appendRaw(data: Data([0]))
            try value.encode(scaleEncoder: scaleEncoder)
        case .failure(let error):
            scaleEncoder.appendRaw(data: Data([1]))
            try error.encode(scaleEncoder: scaleEncoder)
        }
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let mode = try scaleDecoder.read(count: 1)[0]
        try scaleDecoder.confirm(count: 1)

        switch mode {
        case 0:
            let value = try Success.init(scaleDecoder: scaleDecoder)
            self = .success(value)
        case 1:
            let error = try Failure.init(scaleDecoder: scaleDecoder)
            self = .failure(error)
        default:
            throw ScaleOptionalDecodingError.invalidPrefix
        }
    }
}
