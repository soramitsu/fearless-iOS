import BigInt
import Foundation
import SSFUtils

public struct PolkaswapPoolReserves: Codable {
    @StringCodable public var reserves: BigUInt
    @StringCodable public var fee: BigUInt
    
    public init(reserves: BigUInt, fee: BigUInt) {
        self.reserves = reserves
        self.fee = fee
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.reserves = try container.decode(StringCodable<BigUInt>.self).wrappedValue
        self.fee = try container.decode(StringCodable<BigUInt>.self).wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.reserves)
        try container.encode(self.fee)
    }
}

extension PolkaswapPoolReserves: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try reserves.encode(scaleEncoder: scaleEncoder)
        try fee.encode(scaleEncoder: scaleEncoder)
    }
    
    public init(scaleDecoder: ScaleDecoding) throws {
        reserves = try BigUInt(scaleDecoder: scaleDecoder)
        fee = try BigUInt(scaleDecoder: scaleDecoder)
    }
}
