import Foundation
import SSFModels
import SSFUtils

public struct LiquidityPoolProperties: Codable, Hashable {
    let reservesId: AccountId
    let feeId: AccountId
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.reservesId = try container.decode(AccountId.self)
        self.feeId = try container.decode(AccountId.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.reservesId)
        try container.encode(self.feeId)
    }
}

extension LiquidityPoolProperties: ScaleCodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        reservesId = try AccountId(scaleDecoder: scaleDecoder)
        feeId = try AccountId(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try reservesId.encode(scaleEncoder: scaleEncoder)
        try feeId.encode(scaleEncoder: scaleEncoder)
    }
}
