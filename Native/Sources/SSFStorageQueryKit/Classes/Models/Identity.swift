import Foundation
import SSFUtils

public struct Identity: Decodable {
    public let info: IdentityInfo
}

public struct IdentityInfo: Decodable {
    public let additional: [IdentityAddition]
    public let display: ChainData
    public let legal: ChainData
    public let web: ChainData
    public let riot: ChainData
    public let email: ChainData
    public let image: ChainData
    public let twitter: ChainData
}

public struct IdentityAddition: Decodable {
    public let field: ChainData
    public let value: ChainData

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        field = try container.decode(ChainData.self)
        value = try container.decode(ChainData.self)
    }
}
