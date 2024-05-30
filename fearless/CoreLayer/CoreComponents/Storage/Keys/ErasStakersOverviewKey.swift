import Foundation
import SSFUtils

public struct ErasStakersOverviewKey: Decodable {
    @StringCodable var era: UInt32
    let accountId: AccountId

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        era = try container.decode(StringScaleMapper<UInt32>.self).value
        accountId = try container.decode(Data.self)
    }

    public init(scaleDecoder: ScaleDecoding) throws {
        era = try UInt32(scaleDecoder: scaleDecoder)
        accountId = try Data(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try era.encode(scaleEncoder: scaleEncoder)
        try accountId.encode(scaleEncoder: scaleEncoder)
    }
}
