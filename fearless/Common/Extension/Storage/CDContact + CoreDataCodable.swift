import Foundation
import RobinHood
import CoreData

extension CDContact: CoreDataCodable {
    public func populate(
        from decoder: Decoder,
        using _: NSManagedObjectContext
    ) throws {
        let container = try decoder.container(keyedBy: Contact.CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        chainId = try container.decode(String.self, forKey: .chainId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Contact.CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(chainId, forKey: .chainId)
    }
}
