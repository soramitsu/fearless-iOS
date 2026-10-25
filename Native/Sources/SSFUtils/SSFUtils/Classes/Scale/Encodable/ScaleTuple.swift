import Foundation

public typealias ScaleCodableMapKey = (ScaleCodable & Decodable & Hashable & Equatable)

public struct ScaleTuple<T1: ScaleCodableMapKey, T2: ScaleCodableMapKey>: ScaleCodableMapKey {
    public let first: T1
    public let second: T2

    public init(first: T1, second: T2) {
        self.first = first
        self.second = second
    }
    
    enum CodingKeys: CodingKey {
        case first
        case second
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.first = try container.decode(T1.self)
        self.second = try container.decode(T2.self)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        first = try T1(scaleDecoder: scaleDecoder)
        second = try T2(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try first.encode(scaleEncoder: scaleEncoder)
        try second.encode(scaleEncoder: scaleEncoder)
    }
}
