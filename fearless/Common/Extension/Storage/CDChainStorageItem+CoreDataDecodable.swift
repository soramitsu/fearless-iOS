import Foundation
import CoreData
import RobinHood

extension CDChainStorageItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: ChainStorageItem.CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        data = try container.decode(Data.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ChainStorageItem.CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(data, forKey: .data)
    }
}
