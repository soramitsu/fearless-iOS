import Foundation
import CoreData
import RobinHood

extension CDPhishingItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let phishingItem = try PhishingItem(from: decoder)

        identifier = phishingItem.identifier
        source = phishingItem.source
        publicKey = phishingItem.publicKey
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PhishingItem.CodingKeys.self)

      try container.encode(source, forKey: .source)
      try container.encode(publicKey, forKey: .publicKey)
    }
}
