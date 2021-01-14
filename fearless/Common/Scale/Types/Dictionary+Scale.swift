import Foundation
import FearlessUtils

extension Dictionary: ScaleCodable where Dictionary.Key: ScaleCodable, Dictionary.Value: ScaleCodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        let pairList = try Array<Pair<Dictionary.Key, Dictionary.Value>>(scaleDecoder: scaleDecoder)

        self = pairList.reduce(into: [:]) { (result, pair) in
            result[pair.first] = pair.second
        }
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        let pairList = map { pair in
            Pair(first: pair.key, second: pair.value)
        }

        try pairList.encode(scaleEncoder: scaleEncoder)
    }
}
