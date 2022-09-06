import Foundation
import RobinHood
import CoreData

extension CDScamInfo: CoreDataCodable {
    public func populate(
        from decoder: Decoder,
        using _: NSManagedObjectContext
    ) throws {
        let container = try decoder.container(keyedBy: ScamInfo.CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        type = try container.decode(String.self, forKey: .type)
        subtype = try container.decode(String.self, forKey: .subtype)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ScamInfo.CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(type, forKey: .type)
        try container.encode(subtype, forKey: .subtype)
    }
}
