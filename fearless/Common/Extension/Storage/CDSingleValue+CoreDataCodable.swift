import Foundation
import RobinHood
import CoreData

extension CDSingleValue: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case payload
    }

    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        payload = try container.decode(Data.self, forKey: .payload)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(payload, forKey: .payload)
    }
}
