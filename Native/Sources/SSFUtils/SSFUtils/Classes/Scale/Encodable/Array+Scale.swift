import BigInt
import Foundation

extension Array: ScaleCodable where Element: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try BigUInt(count).encode(scaleEncoder: scaleEncoder)

        for item in self {
            try item.encode(scaleEncoder: scaleEncoder)
        }
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        let count = try UInt(BigUInt(scaleDecoder: scaleDecoder))

        self = try (0 ..< count).map { _ in try Element(scaleDecoder: scaleDecoder) }
    }
}
