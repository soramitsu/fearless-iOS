import CoreData
import Foundation
import RobinHood
import SSFPools

extension CDLiquidityPair: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDLiquidityPair.pairId) }

    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: LiquidityPair.CodingKeys.self)

        pairId = try container.decode(String.self, forKey: .pairId)
        chainId = try container.decode(String.self, forKey: .chainId)
        baseAssetId = try container.decode(String.self, forKey: .baseAssetId)
        targetAssetId = try container.decode(String.self, forKey: .targetAssetId)
        rewardAssetId = try container.decode(String.self, forKey: .rewardAssetId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LiquidityPair.CodingKeys.self)

        try container.encode(pairId, forKey: .pairId)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(baseAssetId, forKey: .baseAssetId)
        try container.encode(targetAssetId, forKey: .targetAssetId)
        try container.encode(rewardAssetId, forKey: .rewardAssetId)
    }
}
