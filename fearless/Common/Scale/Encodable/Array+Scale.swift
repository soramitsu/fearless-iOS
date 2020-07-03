import Foundation
import BigInt

extension Array: ScaleCodable where Element: ScaleCodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        try BigUInt(self.count).encode(scaleEncoder: scaleEncoder)

        for item in self {
            try item.encode(scaleEncoder: scaleEncoder)
        }
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let count = UInt(try BigUInt(scaleDecoder: scaleDecoder))

        self = try (0..<count).map { _ in try Element.init(scaleDecoder: scaleDecoder) }
    }
}
