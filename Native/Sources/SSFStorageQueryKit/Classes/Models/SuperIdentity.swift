import Foundation
import SSFUtils

public struct SuperIdentity: Codable {
    public let parentAccountId: Data
    public let data: ChainData

    public var name: String? {
        if case let .raw(value) = data {
            return String(data: value, encoding: .utf8)
        } else {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        parentAccountId = try container.decode(Data.self)
        data = try container.decode(ChainData.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(parentAccountId)
        try container.encode(data)
    }
}
