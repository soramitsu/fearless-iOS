import Foundation
import SSFModels
import SSFUtils

public struct PoolProvidersStorageKey: Codable, Hashable {
    let reservesId: AccountId
    let accountId: AccountId
    
    public init(reservesId: AccountId, accountId: AccountId) {
        self.reservesId = reservesId
        self.accountId = accountId
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.reservesId = try container.decode(AccountId.self)
        self.accountId = try container.decode(AccountId.self)
        
        print("PoolProvidersStorageKey reservesId: ", reservesId.toHex())
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.reservesId)
        try container.encode(self.accountId)
    }
}

extension PoolProvidersStorageKey: ScaleCodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        reservesId = try AccountId(scaleDecoder: scaleDecoder)
        accountId = try AccountId(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try reservesId.encode(scaleEncoder: scaleEncoder)
        try accountId.encode(scaleEncoder: scaleEncoder)
    }
}
