import Foundation
import SSFUtils

public struct ErasStakersPagedKey: Decodable {
    @StringCodable var era: UInt32
    let accountId: AccountId
    @StringCodable var page: UInt32

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        era = try container.decode(StringScaleMapper<UInt32>.self).value
        accountId = try container.decode(Data.self)
        page = try container.decode(StringScaleMapper<UInt32>.self).value
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        era = try UInt32(scaleDecoder: scaleDecoder)
        accountId = try Data(scaleDecoder: scaleDecoder)
        page = try UInt32(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try era.encode(scaleEncoder: scaleEncoder)
        try accountId.encode(scaleEncoder: scaleEncoder)
        try page.encode(scaleEncoder: scaleEncoder)
    }
}
