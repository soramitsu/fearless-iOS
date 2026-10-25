import CoreData
import Foundation
import RobinHood
import SSFPools

extension CDAccountPool: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDAccountPool.poolId) }

    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: AccountPool.CodingKeys.self)

        poolId = try container.decode(String.self, forKey: .poolId)
        accountId = try container.decode(String.self, forKey: .accountId)
        chainId = try container.decode(String.self, forKey: .chainId)
        baseAssetId = try container.decode(String.self, forKey: .baseAssetId)
        targetAssetId = try container.decode(String.self, forKey: .targetAssetId)
        rewardAssetId = try container.decode(String.self, forKey: .rewardAssetId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AccountPool.CodingKeys.self)

        try container.encode(poolId, forKey: .poolId)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(baseAssetId, forKey: .baseAssetId)
        try container.encode(targetAssetId, forKey: .targetAssetId)
        try container.encode(rewardAssetId, forKey: .rewardAssetId)
    }
}
