import Foundation
import CoreData
import RobinHood

extension CDConnectionItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: ConnectionItem.CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        identifier = try container.decode(String.self, forKey: .url)
        networkType = try container.decode(Int16.self, forKey: .type)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConnectionItem.CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(identifier, forKey: .url)
        try container.encode(networkType, forKey: .type)
    }
}
